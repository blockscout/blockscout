defmodule Indexer.Fetcher.Scroll.Batch do
  @moduledoc """
  The module for scanning L1 RPC node for the `CommitBatch` and `FinalizeBatch` events
  which commit and finalize Scroll batches.

  The main function splits the whole block range by chunks and scans L1 Scroll Chain contract
  for the batch logs (events) for each chunk. The found events are handled and then imported to the
  `scroll_batches` and `scroll_batch_bundles` database tables.

  After historical block range is covered, the process switches to realtime mode and
  searches for the batch events in every new block. Reorg blocks are taken into account.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [hash_to_binary: 1]

  alias ABI.{FunctionSelector, TypeDecoder}
  alias Ecto.Multi
  alias EthereumJSONRPC.Logs
  alias Explorer.Chain.Block.Range, as: BlockRange
  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Explorer.Chain.Scroll.{Batch, BatchBundle, Reader}
  alias Explorer.{Chain, Repo}
  alias Indexer.Fetcher.RollupL1ReorgMonitor
  alias Indexer.Fetcher.Scroll.Helper, as: ScrollHelper
  alias Indexer.Helper
  alias Indexer.Prometheus.Instrumenter

  # 32-byte signature of the event CommitBatch(uint256 indexed batchIndex, bytes32 indexed batchHash)
  @commit_batch_event "0x2c32d4ae151744d0bf0b9464a3e897a1d17ed2f1af71f7c9a75f12ce0d28238f"

  # 32-byte signature of the event FinalizeBatch(uint256 indexed batchIndex, bytes32 indexed batchHash, bytes32 stateRoot, bytes32 withdrawRoot)
  @finalize_batch_event "0x26ba82f907317eedc97d0cbef23de76a43dd6edb563bdb6e9407645b950a7a2d"

  @fetcher_name :scroll_batch

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl GenServer
  def handle_continue(_, state) do
    Logger.metadata(fetcher: @fetcher_name)
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :init_with_delay, 2000)
    {:noreply, state}
  end

  # Validates parameters and initiates searching of the events.
  #
  # When first launch, the events searching will start from the first block
  # and end on the `safe` block (or `latest` one if `safe` is not available).
  # If this is not the first launch, the process will start from the block which was
  # the last on the previous launch.
  @impl GenServer
  def handle_info(:init_with_delay, _state) do
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_undefined, false} <- {:start_block_undefined, is_nil(env[:start_block])},
         _ <- RollupL1ReorgMonitor.wait_for_start(__MODULE__),
         rpc = l1_rpc_url(),
         {:rpc_undefined, false} <- {:rpc_undefined, is_nil(rpc)},
         {:scroll_chain_contract_address_is_valid, true} <-
           {:scroll_chain_contract_address_is_valid, Helper.address_correct?(env[:scroll_chain_contract])},
         {:eip4844_blobs_api_url_undefined, false} <-
           {:eip4844_blobs_api_url_undefined, env[:eip4844_blobs_api_url] == ""},
         start_block = env[:start_block],
         true <- start_block > 0,
         {last_l1_block_number, last_l1_transaction_hash} = Reader.last_l1_batch_item(),
         json_rpc_named_arguments = Helper.json_rpc_named_arguments(rpc),
         {:ok, block_check_interval, safe_block} <- Helper.get_block_check_interval(json_rpc_named_arguments),
         {:start_block_valid, true, _, _} <-
           {:start_block_valid,
            (start_block <= last_l1_block_number || last_l1_block_number == 0) && start_block <= safe_block,
            last_l1_block_number, safe_block},
         {:ok, last_l1_transaction} <-
           Helper.get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
         # here we check for the last known L1 transaction existence to make sure there wasn't reorg
         # on L1 while the instance was down, and so we can use `last_l1_block_number` as the starting point
         {:l1_transaction_not_found, false} <-
           {:l1_transaction_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_transaction)} do
      l1_chain_id =
        case EthereumJSONRPC.fetch_chain_id(json_rpc_named_arguments) do
          {:ok, id} ->
            id

          {:error, reason} ->
            Logger.warning(
              "Cannot get Chain ID from L1 RPC. Reason: #{inspect(reason)}. The module will use fallback values from INDEXER_BEACON_BLOB_FETCHER_* env variables."
            )

            nil
        end

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         block_check_interval: block_check_interval,
         scroll_chain_contract: env[:scroll_chain_contract],
         json_rpc_named_arguments: json_rpc_named_arguments,
         end_block: safe_block,
         start_block: max(start_block, last_l1_block_number),
         eth_get_logs_range_size:
           Application.get_all_env(:indexer)[Indexer.Fetcher.Scroll][:l1_eth_get_logs_range_size],
         eip4844_blobs_api_url: Helper.trim_url(env[:eip4844_blobs_api_url]),
         l1_chain_id: l1_chain_id
       }}
    else
      {:start_block_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, %{}}

      {:rpc_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, %{}}

      {:scroll_chain_contract_address_is_valid, false} ->
        Logger.error("L1 ScrollChain contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:eip4844_blobs_api_url_undefined, true} ->
        Logger.error(
          "Blockscout Blobs API URL is not defined. Please, check INDEXER_SCROLL_L1_BATCH_BLOCKSCOUT_BLOBS_API_URL env variable."
        )

        {:stop, :normal, %{}}

      {:start_block_valid, false, last_l1_block_number, safe_block} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and scroll_batches table.")
        Logger.error("last_l1_block_number = #{inspect(last_l1_block_number)}")
        Logger.error("safe_block = #{inspect(safe_block)}")
        {:stop, :normal, %{}}

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, latest block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        {:stop, :normal, %{}}

      {:l1_transaction_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check scroll_batches table."
        )

        {:stop, :normal, %{}}

      _ ->
        Logger.error("L1 Start Block is invalid or zero.")
        {:stop, :normal, %{}}
    end
  end

  @doc """
  The main function that scans RPC node for the batch logs (events), parses them,
  and imports to the database (into the `scroll_batches` and `scroll_batch_bundles` tables).

  The function splits a given block range by chunks and scans the Scroll Chain contract
  for the batch logs (events) for each chunk. The found events are handled and then imported
  to the `scroll_batches` and `scroll_batch_bundles` database tables.

  After historical block range is covered, the function switches to realtime mode and
  searches for the batch events in every new block. Reorg blocks are taken into account.

  ## Parameters
  - `:continue`: The message that triggers the working loop.
  - `state`: The state map containing needed data such as the chain contract address and the block range.

  ## Returns
  - {:noreply, state} tuple with the updated block range in the `state` to scan logs in.
  """
  @impl GenServer
  def handle_info(
        :continue,
        %{
          block_check_interval: block_check_interval,
          scroll_chain_contract: scroll_chain_contract,
          json_rpc_named_arguments: json_rpc_named_arguments,
          end_block: end_block,
          start_block: start_block,
          eth_get_logs_range_size: eth_get_logs_range_size,
          eip4844_blobs_api_url: eip4844_blobs_api_url,
          l1_chain_id: l1_chain_id
        } = state
      ) do
    time_before = Timex.now()

    last_written_block =
      start_block..end_block
      |> Enum.chunk_every(eth_get_logs_range_size)
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = List.first(current_chunk)
        chunk_end = List.last(current_chunk)

        if chunk_start <= chunk_end do
          Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, :L1)

          {batches, bundles, start_by_final_batch_number} =
            {chunk_start, chunk_end}
            |> get_logs_all(scroll_chain_contract, json_rpc_named_arguments)
            |> prepare_items(json_rpc_named_arguments, eip4844_blobs_api_url, l1_chain_id)

          import_items(batches, bundles, start_by_final_batch_number)

          last_batch =
            batches
            |> Enum.max_by(& &1.number, fn -> nil end)

          # credo:disable-for-next-line
          if last_batch do
            Instrumenter.set_latest_batch(last_batch.number, last_batch.commit_timestamp)
          end

          Helper.log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(batches)} L1 batch(es), #{Enum.count(bundles)} L1 bundle(s)",
            :L1
          )
        end

        reorg_block = RollupReorgMonitorQueue.reorg_block_pop(__MODULE__)

        if !is_nil(reorg_block) && reorg_block > 0 do
          reorg_handle(reorg_block)
          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1

    {:ok, new_end_block} =
      Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number())

    delay =
      if new_end_block == last_written_block do
        # there is no new block, so wait for some time to let the chain issue the new block
        max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
      else
        0
      end

    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @doc """
    Returns L1 RPC URL for this module.
    Returns `nil` if not defined.
  """
  @spec l1_rpc_url() :: binary() | nil
  def l1_rpc_url do
    ScrollHelper.l1_rpc_url()
  end

  @doc """
    Determines if `Indexer.Fetcher.RollupL1ReorgMonitor` module must be up
    for this module.

    ## Returns
    - `true` if the reorg monitor must be active, `false` otherwise.
  """
  @spec requires_l1_reorg_monitor?() :: boolean()
  def requires_l1_reorg_monitor? do
    module_config = Application.get_all_env(:indexer)[__MODULE__]
    not is_nil(module_config[:start_block])
  end

  # Fetches `CommitBatch` and `FinalizeBatch` events of the Scroll Chain contract from an RPC node
  # for the given range of L1 blocks.
  @spec get_logs_all({non_neg_integer(), non_neg_integer()}, binary(), EthereumJSONRPC.json_rpc_named_arguments()) :: [
          %{atom() => any()}
        ]
  defp get_logs_all({chunk_start, chunk_end}, scroll_chain_contract, json_rpc_named_arguments) do
    {:ok, result} =
      Helper.get_logs(
        chunk_start,
        chunk_end,
        scroll_chain_contract,
        [[@commit_batch_event, @finalize_batch_event]],
        json_rpc_named_arguments,
        0,
        Helper.infinite_retries_number()
      )

    Logs.elixir_to_params(result)
  end

  # Extracts transaction inputs for specified transaction hashes from a list of blocks.
  #
  # ## Parameters
  # - `blocks`: A list of block maps, each containing a "transactions" key with transaction data.
  # - `transaction_hashes`: A list of transaction hashes to filter for.
  #
  # ## Returns
  # A map where keys are transaction hashes and values are the corresponding transaction inputs and blob versioned hashes.
  @spec get_transaction_input_by_hash([%{String.t() => any()}], [binary()]) :: %{
          binary() => {binary(), [binary()] | [] | nil}
        }
  defp get_transaction_input_by_hash(blocks, transaction_hashes) do
    Enum.reduce(blocks, %{}, fn block, acc ->
      block
      |> Map.get("transactions", [])
      |> Enum.filter(fn transaction ->
        Enum.member?(transaction_hashes, transaction["hash"])
      end)
      |> Enum.map(fn transaction ->
        {transaction["hash"], {transaction["input"], transaction["blobVersionedHashes"] || []}}
      end)
      |> Enum.into(%{})
      |> Map.merge(acc)
    end)
  end

  # Extracts the L2 block range from the calldata or EIP-4844 blob of a batch commitment transaction.
  #
  # This function decodes the input data from either a `commitBatch` or
  # `commitBatchWithBlobProof` function call. If the call is not exists, it takes the
  # batch info from EIP-4844 blob. Determines the range of L2 block numbers included in the batch.
  #
  # ## Parameters
  # - `input`: A binary string representing the input data of a batch commitment transaction.
  # - `blob_versioned_hash`: A binary string representing the EIP-4844 blob hash (for post-Euclid phase).
  # - `eip4844_blobs_api_url`: URL of Blockscout Blobs API to get EIP-4844 blobs (for post-Euclid phase).
  # - `block_timestamp`: L1 block timestamp of the commitment transaction (for post-Euclid phase).
  # - `batch_number`: The batch number corresponding to the batch commitment transaction (for post-Euclid phase).
  # - `l1_chain_id`: Chain ID for L1 (for post-Euclid phase).
  #
  # ## Returns
  # - A `BlockRange.t()` struct containing the minimum and maximum L2 block numbers included in the batch.
  # - `nil` if the block range cannot be determined.
  @spec input_to_l2_block_range(
          binary(),
          binary() | nil,
          binary(),
          DateTime.t(),
          non_neg_integer(),
          non_neg_integer() | nil
        ) :: BlockRange.t() | nil
  defp input_to_l2_block_range(
         input,
         blob_versioned_hash,
         eip4844_blobs_api_url,
         block_timestamp,
         batch_number,
         l1_chain_id
       ) do
    chunks =
      input
      |> String.downcase()
      |> case do
        # commitBatch(uint8 _version, bytes _parentBatchHeader, bytes[] _chunks, bytes _skippedL1MessageBitmap)
        "0x1325aca0" <> encoded_params ->
          [_version, _parent_batch_header, chunks, _skipped_l1_message_bitmap] =
            TypeDecoder.decode(
              Base.decode16!(encoded_params, case: :lower),
              %FunctionSelector{
                function: "commitBatch",
                types: [
                  {:uint, 8},
                  :bytes,
                  {:array, :bytes},
                  :bytes
                ]
              }
            )

          chunks

        # commitBatchWithBlobProof(uint8 _version, bytes _parentBatchHeader, bytes[] _chunks, bytes _skippedL1MessageBitmap, bytes _blobDataProof)
        "0x86b053a9" <> encoded_params ->
          [_version, _parent_batch_header, chunks, _skipped_l1_message_bitmap, _blob_data_proof] =
            TypeDecoder.decode(
              Base.decode16!(encoded_params, case: :lower),
              %FunctionSelector{
                function: "commitBatchWithBlobProof",
                types: [
                  {:uint, 8},
                  :bytes,
                  {:array, :bytes},
                  :bytes,
                  :bytes
                ]
              }
            )

          chunks

        # Post-Euclid-phase-2
        # commitBatches(uint8 version, bytes32 parentBatchHash, bytes32 lastBatchHash)
        "0x9bbaa2ba" <> _encoded_params ->
          nil

        # Post-Euclid-phase-2
        # commitAndFinalizeBatch(uint8 version, bytes32 parentBatchHash, (bytes batchHeader, uint256 totalL1MessagesPoppedOverall, bytes32 postStateRoot, bytes32 withdrawRoot, bytes zkProof))
        "0x27dcaf6f" <> _encoded_params ->
          nil
      end

    {:ok, l2_block_range} =
      if is_nil(chunks) do
        # this is post-Euclid phase, so we get L2 block range info from an EIP-4844 blob
        get_l2_block_range_post_euclid(
          eip4844_blobs_api_url,
          blob_versioned_hash,
          block_timestamp,
          batch_number,
          l1_chain_id
        )
      else
        # this is pre-Euclid phase, so we get L2 block range info from the calldata
        get_l2_block_range_pre_euclid(chunks)
      end

    l2_block_range
  end

  # Parses chunks of L2 blocks info taken from calldata of the batch commitment transaction.
  #
  # ## Parameters
  # - `chunks`: The list of chunks in the format defined in https://github.com/scroll-tech/scroll-contracts/blob/main/src/libraries/codec/ChunkCodecV1.sol.
  #
  # ## Returns
  # - `{:ok, BlockRange.t()}` tuple containing the block range.
  @spec get_l2_block_range_pre_euclid(list()) :: {:ok, BlockRange.t()} | {:error, any()}
  defp get_l2_block_range_pre_euclid(chunks) do
    chunks
    |> Enum.reduce([], fn chunk, acc ->
      <<chunk_length::size(8), chunk_data::binary>> = chunk

      chunk_l2_block_numbers =
        Enum.map(Range.new(0, chunk_length - 1, 1), fn i ->
          chunk_data
          |> :binary.part(i * 60, 8)
          |> :binary.decode_unsigned()
        end)

      acc ++ chunk_l2_block_numbers
    end)
    |> Enum.min_max()
    |> BlockRange.cast()
  end

  # Gets and parses EIP-4844 blob from the remote Blockscout Blobs API (or directly from Beacon Node as fallback data source).
  #
  # ## Parameters
  # - `eip4844_blobs_api_url`: URL of Blockscout Blobs API.
  # - `blob_hash`: The blob versioned hash in form of `0x` string.
  # - `block_timestamp`: Timestamp of L1 block to convert it to beacon slot (when using fallback request to the Beacon Node).
  # - `batch_number`: The batch number for logging purposes.
  # - `l1_chain_id`: ID of L1 chain to automatically define parameters for calculating beacon slot (when using fallback
  #   request to the Beacon Node). If ID is `nil` or unknown, the parameters are taken from the fallback
  #   INDEXER_BEACON_BLOB_FETCHER_REFERENCE_SLOT, INDEXER_BEACON_BLOB_FETCHER_REFERENCE_TIMESTAMP, INDEXER_BEACON_BLOB_FETCHER_SLOT_DURATION
  #   env variables.
  #
  # ## Returns
  # - `{:ok, BlockRange.t() | nil}` tuple containing the block range (or `nil` if the blob is invalid or cannot be read).
  @spec get_l2_block_range_post_euclid(String.t(), String.t(), DateTime.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, BlockRange.t() | nil}
  defp get_l2_block_range_post_euclid(eip4844_blobs_api_url, blob_hash, block_timestamp, batch_number, l1_chain_id) do
    case get_blob_data_from_server(eip4844_blobs_api_url, blob_hash, block_timestamp, l1_chain_id) do
      {nil, _} ->
        Logger.warning(
          "Cannot get the blob #{blob_hash} from the Blockscout Blobs API and Beacon Node. L2 block range will be unknown for the batch ##{batch_number}."
        )

        {:ok, nil}

      {encoded_payload, source} ->
        decoded_payload = Batch.decode_eip4844_blob(encoded_payload)

        if is_nil(decoded_payload) do
          Logger.warning(
            "Cannot decode the blob #{blob_hash} taken from the #{source}. L2 block range will be unknown for the batch ##{batch_number}."
          )

          {:ok, nil}
        else
          Logger.info(
            "L2 block range for the batch ##{batch_number} is taken from the #{source}. Blob hash: #{blob_hash}"
          )

          <<_prev_l1_message_queue_hash::binary-size(32), _post_l1_message_queue_hash::binary-size(32),
            initial_l2_block_number::size(64), num_blocks::size(16), _::binary>> = decoded_payload

          BlockRange.cast({initial_l2_block_number, initial_l2_block_number + num_blocks - 1})
        end
    end
  end

  # Sends an HTTP request to Blockscout Blobs API (or Beacon Node as fallback source) to get EIP-4844 blob data
  # by blob's versioned hash.
  #
  # ## Parameters
  # - `eip4844_blobs_api_url`: URL of Blockscout Blobs API.
  # - `blob_hash`: The blob versioned hash in form of `0x` string.
  # - `block_timestamp`: Timestamp of L1 block to convert it to beacon slot.
  # - `l1_chain_id`: ID of L1 chain to automatically define parameters for calculating beacon slot.
  #   If ID is `nil` or unknown, the parameters are taken from the fallback INDEXER_BEACON_BLOB_FETCHER_REFERENCE_SLOT,
  #   INDEXER_BEACON_BLOB_FETCHER_REFERENCE_TIMESTAMP, INDEXER_BEACON_BLOB_FETCHER_SLOT_DURATION env variables.
  #
  # ## Returns
  # - `{binary() | nil, source}` tuple where the first item is a binary with the blob data in case of success (or `nil`
  #   in case of failure), and the second item is the data source name for logging purposes.
  @spec get_blob_data_from_server(String.t(), String.t(), DateTime.t(), non_neg_integer() | nil) ::
          {binary() | nil, String.t()}
  defp get_blob_data_from_server(eip4844_blobs_api_url, blob_hash, block_timestamp, l1_chain_id) do
    with {:ok, response} <- Helper.http_get_request(eip4844_blobs_api_url <> "/" <> blob_hash),
         blob_data = Map.get(response, "blob_data"),
         false <- is_nil(blob_data) do
      {hash_to_binary(blob_data), "Blockscout Blobs API"}
    else
      _ ->
        Logger.warning(
          "Cannot get the blob #{blob_hash} from Blockscout Blobs API. Trying to get that from the Beacon Node..."
        )

        {Helper.get_eip4844_blob_from_beacon_node(blob_hash, block_timestamp, l1_chain_id), "Beacon Node"}
    end
  end

  # Imports batches and bundles into the database.
  #
  # ## Parameters
  # - `batches`: List of batch data to be imported.
  # - `bundles`: List of bundle data to be imported.
  # - `start_by_final_batch_number`: A map defining start batch number by final one for bundles.
  #
  # ## Returns
  # - The result of the database operations.
  @spec import_items([Batch.to_import()], [%{atom() => any()}], %{non_neg_integer() => non_neg_integer()}) :: any()
  defp import_items([], [], _), do: :ok

  defp import_items(batches, bundles, start_by_final_batch_number) do
    {:ok, inserts} =
      Chain.import(%{
        scroll_batch_bundles: %{params: bundles},
        scroll_batches: %{params: batches},
        timeout: :infinity
      })

    multi =
      inserts
      |> Map.get(:insert_scroll_batch_bundles, [])
      |> Enum.reduce(Multi.new(), fn bundle, multi_acc ->
        start_batch_number = start_by_final_batch_number[bundle.final_batch_number]

        Multi.update_all(
          multi_acc,
          bundle.id,
          from(b in Batch, where: b.number >= ^start_batch_number and b.number <= ^bundle.final_batch_number),
          set: [bundle_id: bundle.id]
        )
      end)

    Repo.transaction(multi)
  end

  # Prepares batch and bundle items from Scroll events for database import.
  #
  # This function processes a list of CommitBatch and FinalizeBatch events,
  # extracting relevant information to create batch and bundle records.
  #
  # ## Parameters
  # - `events`: A list of Scroll events to process.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  # - `eip4844_blobs_api_url`: URL of Blockscout Blobs API to get EIP-4844 blobs.
  # - `l1_chain_id`: Chain ID for L1.
  #
  # ## Returns
  # A tuple containing two lists and a map:
  # - List of batches, ready for import to the DB.
  # - List of structures describing L1 transactions finalizing batches in form of
  #   bundles, ready for import to the DB.
  # - A map defining start batch number by final one for bundles.
  @spec prepare_items(
          [%{atom() => any()}],
          EthereumJSONRPC.json_rpc_named_arguments(),
          String.t(),
          non_neg_integer() | nil
        ) ::
          {[Batch.to_import()], [%{atom() => any()}], %{non_neg_integer() => non_neg_integer()}}
  defp prepare_items([], _, _, _), do: {[], [], %{}}

  defp prepare_items(events, json_rpc_named_arguments, eip4844_blobs_api_url, l1_chain_id) do
    blocks = Helper.get_blocks_by_events(events, json_rpc_named_arguments, Helper.infinite_retries_number(), true)

    ordered_batch_numbers_by_transaction_hash =
      events
      |> Enum.filter(&(&1.first_topic == @commit_batch_event))
      |> Enum.sort(&(&1.index < &2.index))
      |> Enum.reduce(%{}, fn event, acc ->
        batch_number = quantity_to_integer(event.second_topic)
        batch_numbers = [batch_number | Map.get(acc, event.transaction_hash, [])]
        Map.put(acc, event.transaction_hash, batch_numbers)
      end)
      |> Enum.map(fn {transaction_hash, batch_numbers} -> {transaction_hash, Enum.reverse(batch_numbers)} end)
      |> Enum.into(%{})

    commit_transaction_hashes = Map.keys(ordered_batch_numbers_by_transaction_hash)
    commit_transaction_input_by_hash = get_transaction_input_by_hash(blocks, commit_transaction_hashes)

    timestamps =
      blocks
      |> Enum.reduce(%{}, fn block, acc ->
        block_number = quantity_to_integer(Map.get(block, "number"))
        {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
        Map.put(acc, block_number, timestamp)
      end)

    prev_final_batch_number = Reader.last_final_batch_number()

    {_, batches, bundles, start_by_final_batch_number} =
      events
      |> Enum.reduce({prev_final_batch_number, [], [], %{}}, fn event,
                                                                {prev_final_batch_number_acc, batches_acc, bundles_acc,
                                                                 start_by_final_batch_number_acc} ->
        block_number = quantity_to_integer(event.block_number)
        block_timestamp = Map.get(timestamps, block_number)
        batch_number = quantity_to_integer(event.second_topic)

        if event.first_topic == @commit_batch_event do
          new_batch =
            handle_commit_batch_event(
              event.transaction_hash,
              block_number,
              block_timestamp,
              batch_number,
              commit_transaction_input_by_hash,
              ordered_batch_numbers_by_transaction_hash,
              eip4844_blobs_api_url,
              l1_chain_id
            )

          {prev_final_batch_number_acc, [new_batch | batches_acc], bundles_acc, start_by_final_batch_number_acc}
        else
          new_bundle = handle_finalize_batch_event(event.transaction_hash, block_number, block_timestamp, batch_number)

          new_start_by_final_batch_number_acc =
            Map.put(start_by_final_batch_number_acc, batch_number, prev_final_batch_number_acc + 1)

          {batch_number, batches_acc, [new_bundle | bundles_acc], new_start_by_final_batch_number_acc}
        end
      end)

    {batches, bundles, start_by_final_batch_number}
  end

  # Handles the `CommitBatch` event and prepares a map describing a batch to import to the database.
  #
  # ## Parameters
  # - `transaction_hash`: The commit L1 transaction hash in form of `0x` string.
  # - `block_number`: The commit L1 block number.
  # - `block_timestamp`: The commit L1 block timestamp.
  # - `batch_number`: The batch number.
  # - `commit_transaction_input_by_hash`: A map containing the commit transaction inputs by their hashes.
  #   The map key is a transaction hash, the value is the input in form of `0x` string.
  # - `ordered_batch_numbers_by_transaction_hash`: A map containing the commit batch numbers by commit transaction hashes.
  #   The map key is a transaction hash, the value is the list of batch numbers committed by the transaction.
  # - `eip4844_blobs_api_url`: URL of Blockscout Blobs API to get EIP-4844 blobs.
  # - `l1_chain_id`: Chain ID for L1.
  #
  # ## Returns
  # - A map describing a batch, see `Batch.to_import()`.
  @spec handle_commit_batch_event(
          String.t(),
          non_neg_integer(),
          DateTime.t(),
          non_neg_integer(),
          map(),
          map(),
          String.t(),
          non_neg_integer()
        ) :: Batch.to_import()
  defp handle_commit_batch_event(
         transaction_hash,
         block_number,
         block_timestamp,
         batch_number,
         commit_transaction_input_by_hash,
         ordered_batch_numbers_by_transaction_hash,
         eip4844_blobs_api_url,
         l1_chain_id
       ) do
    {l2_block_range, container} =
      if batch_number == 0 do
        {:ok, range} = BlockRange.cast("[0,0]")
        {range, :in_calldata}
      else
        {input, blob_versioned_hashes} =
          commit_transaction_input_by_hash
          |> Map.get(transaction_hash)

        container =
          if blob_versioned_hashes == [] do
            :in_calldata
          else
            :in_blob4844
          end

        batch_index =
          ordered_batch_numbers_by_transaction_hash
          |> Map.get(transaction_hash, [])
          |> Enum.find_index(&(&1 == batch_number))

        blob_versioned_hash = Enum.at(blob_versioned_hashes, batch_index)

        {input_to_l2_block_range(
           input,
           blob_versioned_hash,
           eip4844_blobs_api_url,
           block_timestamp,
           batch_number,
           l1_chain_id
         ), container}
      end

    %{
      number: batch_number,
      commit_transaction_hash: transaction_hash,
      commit_block_number: block_number,
      commit_timestamp: block_timestamp,
      l2_block_range: l2_block_range,
      container: container
    }
  end

  # Handles the `FinalizeBatch` event and prepares a map describing a batch bundle to import to the database.
  #
  # ## Parameters
  # - `transaction_hash`: The finalization L1 transaction hash.
  # - `block_number`: The finalization L1 block number.
  # - `block_timestamp`: The finalization L1 block timestamp.
  # - `batch_number`: The final batch number in the bundle.
  #
  # ## Returns
  # - A map describing a batch bundle, see `BatchBundle.to_import()`.
  @spec handle_finalize_batch_event(String.t(), non_neg_integer(), DateTime.t(), non_neg_integer()) ::
          BatchBundle.to_import()
  defp handle_finalize_batch_event(transaction_hash, block_number, block_timestamp, batch_number) do
    %{
      final_batch_number: batch_number,
      finalize_transaction_hash: transaction_hash,
      finalize_block_number: block_number,
      finalize_timestamp: block_timestamp
    }
  end

  # Handles L1 block reorg: removes all batch rows from the `scroll_batches` table
  # created beginning from the reorged block. Also, removes the corresponding rows from
  # the `scroll_batch_bundles` table.
  #
  # ## Parameters
  # - `reorg_block`: the block number where reorg has occurred.
  #
  # ## Returns
  # - nothing
  @spec reorg_handle(non_neg_integer()) :: any()
  defp reorg_handle(reorg_block) do
    bundle_ids =
      Repo.all(
        from(b in Batch,
          select: b.bundle_id,
          where: b.commit_block_number >= ^reorg_block,
          group_by: b.bundle_id
        )
      )

    {:ok, result} =
      Multi.new()
      |> Multi.delete_all(:delete_batches, from(b in Batch, where: b.bundle_id in ^bundle_ids))
      |> Multi.delete_all(
        :delete_bundles,
        from(bb in BatchBundle, where: bb.id in ^bundle_ids or bb.finalize_block_number >= ^reorg_block)
      )
      |> Repo.transaction()

    deleted_batches_count = elem(result.delete_batches, 0)
    deleted_bundles_count = elem(result.delete_bundles, 0)

    if deleted_batches_count > 0 do
      Logger.warning(
        "As L1 reorg was detected, some batches with commit_block_number >= #{reorg_block} were removed from the scroll_batches table. Number of removed rows: #{deleted_batches_count}."
      )
    end

    if deleted_bundles_count > 0 do
      Logger.warning(
        "As L1 reorg was detected, some bundles with finalize_block_number >= #{reorg_block} were removed from the scroll_batch_bundles table. Number of removed rows: #{deleted_bundles_count}."
      )
    end
  end
end
