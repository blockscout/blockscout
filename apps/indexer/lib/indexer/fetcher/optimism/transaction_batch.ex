defmodule Indexer.Fetcher.Optimism.TransactionBatch do
  @moduledoc """
    Fills op_transaction_batches, op_frame_sequence, and op_frame_sequence_blobs DB tables.

    This module parses L1 batch transactions, handles them to retrieve L2 block batches info
    and save it to the database.

    If an L1 transaction is a blob transaction (either EIP-4844, Celestia, etc.), the blob
    is read from the corresponding server by its API URL and parsed to get raw data. Blob
    metadata is saved to op_frame_sequence_blobs DB table.

    According to EIP-4844, an L1 transaction can have more than one blob. Each EIP-4844 blob
    contains a separate frame (part of a frame sequence that encodes a batch), so usually
    L1 EIP-4844 transaction represents a frame sequence.

    Celestia L1 transaction can have only one blob. A batch can be split into several Celestia blobs
    related to different L1 transactions (usually following each other).
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [fetch_blocks_by_range: 2, json_rpc: 2, quantity_to_integer: 1]

  import Explorer.Helper, only: [hash_to_binary: 1, parse_integer: 1]

  alias Ecto.Multi
  alias EthereumJSONRPC.Block.ByHash
  alias EthereumJSONRPC.{Blocks, Contract}
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Hash, RollupReorgMonitorQueue}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Optimism.{FrameSequence, FrameSequenceBlob}
  alias Explorer.Chain.Optimism.TransactionBatch, as: OptimismTransactionBatch
  alias Indexer.Fetcher.{Optimism, RollupL1ReorgMonitor}
  alias Indexer.Helper
  alias Indexer.Prometheus.Instrumenter
  alias Varint.LEB128

  @fetcher_name :optimism_transaction_batches

  @compressor_brotli 1
  @counter_type "optimism_batches_fetcher_last_l1_block_hash"
  @empty_hash "0x0000000000000000000000000000000000000000000000000000000000000000"

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
  def init(args) do
    {:ok, %{json_rpc_named_arguments_l2: args[:json_rpc_named_arguments]}, {:continue, nil}}
  end

  @impl GenServer
  def handle_continue(_, state) do
    Logger.metadata(fetcher: @fetcher_name)
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :init_with_delay, 2000)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        :init_with_delay,
        %{json_rpc_named_arguments_l2: json_rpc_named_arguments_l2} = state
      ) do
    env = Application.get_all_env(:indexer)[__MODULE__]

    optimism_env = Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism]
    system_config = optimism_env[:optimism_l1_system_config]
    optimism_l1_rpc = l1_rpc_url()

    with {:system_config_valid, true} <-
           {:system_config_valid, Helper.address_correct?(system_config)},
         {:genesis_block_l2_invalid, false} <-
           {:genesis_block_l2_invalid, is_nil(env[:genesis_block_l2]) or env[:genesis_block_l2] < 0},
         _ <- RollupL1ReorgMonitor.wait_for_start(__MODULE__),
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_l1_rpc)},
         json_rpc_named_arguments = Helper.json_rpc_named_arguments(optimism_l1_rpc),
         {:system_config_read, {start_block_l1, batch_inbox, batch_submitter}} <-
           {:system_config_read, read_system_config(system_config, json_rpc_named_arguments)},
         {:batch_inbox_valid, true} <- {:batch_inbox_valid, Helper.address_correct?(batch_inbox)},
         {:batch_submitter_valid, true} <-
           {:batch_submitter_valid, Helper.address_correct?(batch_submitter)},
         true <- start_block_l1 > 0,
         chunk_size = parse_integer(env[:blocks_chunk_size]),
         {:chunk_size_valid, true} <- {:chunk_size_valid, !is_nil(chunk_size) && chunk_size > 0},
         {:block_duration_valid, true} <- {:block_duration_valid, optimism_env[:block_duration] > 0},
         {last_l1_block_number, last_l1_transaction_hash, last_l1_transaction} =
           get_last_l1_item(json_rpc_named_arguments),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         {:l1_transaction_not_found, false} <-
           {:l1_transaction_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_transaction)},
         {:ok, block_check_interval, last_safe_block} <-
           Helper.get_block_check_interval(json_rpc_named_arguments) do
      start_block = max(start_block_l1, last_l1_block_number)

      chain_id_l1 =
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
         batch_inbox: batch_inbox,
         batch_submitter: batch_submitter,
         eip4844_blobs_api_url: Helper.trim_url(env[:eip4844_blobs_api_url]),
         celestia_blobs_api_url: Helper.trim_url(env[:celestia_blobs_api_url]),
         block_check_interval: block_check_interval,
         start_block: start_block,
         end_block: last_safe_block,
         chunk_size: chunk_size,
         incomplete_channels: %{},
         genesis_block_l2: env[:genesis_block_l2],
         block_duration: optimism_env[:block_duration],
         json_rpc_named_arguments: json_rpc_named_arguments,
         json_rpc_named_arguments_l2: json_rpc_named_arguments_l2,
         chain_id_l1: chain_id_l1
       }}
    else
      {:system_config_valid, false} ->
        Logger.error("SystemConfig contract address is invalid or undefined.")
        {:stop, :normal, state}

      {:genesis_block_l2_invalid, true} ->
        Logger.error("L2 genesis block number is undefined or invalid.")
        {:stop, :normal, state}

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, state}

      {:batch_inbox_valid, false} ->
        Logger.error("Batch Inbox address is invalid or not defined.")
        {:stop, :normal, state}

      {:batch_submitter_valid, false} ->
        Logger.error("Batch Submitter address is invalid or not defined.")
        {:stop, :normal, state}

      {:start_block_l1_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and op_transaction_batches table.")

        {:stop, :normal, state}

      {:chunk_size_valid, false} ->
        Logger.error("Invalid blocks chunk size value.")
        {:stop, :normal, state}

      {:block_duration_valid, false} ->
        Logger.error("Check INDEXER_OPTIMISM_BLOCK_DURATION env variable. Its value must be a positive integer.")
        {:stop, :normal, state}

      {:error, error_data} ->
        Logger.error("Cannot get block timestamp by its number due to RPC error: #{inspect(error_data)}")

        {:stop, :normal, state}

      {:l1_transaction_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check op_transaction_batches table."
        )

        {:stop, :normal, state}

      {:system_config_read, nil} ->
        Logger.error("Cannot read SystemConfig contract and fallback envs are not correctly defined.")
        {:stop, :normal, state}

      _ ->
        Logger.error("Batch Start Block is invalid or zero.")
        {:stop, :normal, state}
    end
  end

  # The main handler filtering L1 transactions and parsing them to retrieve
  # batches of L2 blocks.
  #
  # The work is split into chunks (L1 block subranges) of the specified block range.
  # The chunk size is configurable through INDEXER_OPTIMISM_L1_BATCH_BLOCKS_CHUNK_SIZE
  # env variable.
  #
  # When the last block of the range is reached, the handler switches to `(last+1)..latest`
  # block range and then handles the new blocks in realtime. The latest block number is checked
  # every `block_check_interval` milliseconds which is calculated in the init function.
  #
  # ## Parameters (in the `state` param)
  # - `batch_inbox`: L1 address which accepts L1 batch transactions
  # - `batch_submitter`: L1 address which sends L1 batch transactions to the `batch_inbox`
  # - `eip4844_blobs_api_url`: URL of Blockscout Blobs API to get EIP-4844 blobs
  # - `celestia_blobs_api_url`: URL of the server where Celestia blobs can be read from
  # - `block_check_interval`: time interval for checking latest block number
  # - `start_block`: start block number of the block range
  # - `end_block`: end block number of the block range
  # - `chunk_size`: max number of L1 blocks in one chunk
  # - `incomplete_channels`: intermediate map of channels (incomplete frame sequences) in memory
  # - `genesis_block_l2`: Optimism BedRock upgrade L2 block number (used when parsing span batches)
  # - `block_duration`: L2 block duration in seconds (used when parsing span batches)
  # - `json_rpc_named_arguments`: data to connect to L1 RPC server
  # - `json_rpc_named_arguments_l2`: data to connect to L2 RPC server
  # - `chain_id_l1`: chain ID of L1 layer.
  @impl GenServer
  def handle_info(
        :continue,
        %{
          batch_inbox: batch_inbox,
          batch_submitter: batch_submitter,
          eip4844_blobs_api_url: eip4844_blobs_api_url,
          celestia_blobs_api_url: celestia_blobs_api_url,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          chunk_size: chunk_size,
          incomplete_channels: incomplete_channels,
          genesis_block_l2: genesis_block_l2,
          block_duration: block_duration,
          json_rpc_named_arguments: json_rpc_named_arguments,
          json_rpc_named_arguments_l2: json_rpc_named_arguments_l2,
          chain_id_l1: chain_id_l1
        } = state
      ) do
    time_before = Timex.now()

    chunks_number = ceil((end_block - start_block + 1) / chunk_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    {last_written_block, new_incomplete_channels} =
      chunk_range
      |> Enum.reduce_while({start_block - 1, incomplete_channels}, fn current_chunk, {_, incomplete_channels_acc} ->
        chunk_start = start_block + chunk_size * current_chunk
        chunk_end = min(chunk_start + chunk_size - 1, end_block)

        {new_incomplete_channels, last_block_hash} =
          if chunk_end >= chunk_start do
            Helper.log_blocks_chunk_handling(
              chunk_start,
              chunk_end,
              start_block,
              end_block,
              nil,
              :L1
            )

            {:ok, new_incomplete_channels, batches, sequences, blobs, last_block_hash} =
              get_transaction_batches(
                Range.new(chunk_start, chunk_end),
                batch_inbox,
                batch_submitter,
                {genesis_block_l2, block_duration},
                incomplete_channels_acc,
                {json_rpc_named_arguments, json_rpc_named_arguments_l2},
                {eip4844_blobs_api_url, celestia_blobs_api_url, chain_id_l1},
                Helper.infinite_retries_number()
              )

            {batches, sequences, blobs} = remove_duplicates(batches, sequences, blobs)

            {:ok, _} =
              Chain.import(%{
                optimism_frame_sequences: %{params: sequences},
                timeout: :infinity
              })

            {:ok, inserted} =
              Chain.import(%{
                optimism_frame_sequence_blobs: %{params: blobs},
                optimism_transaction_batches: %{params: batches},
                timeout: :infinity
              })

            remove_prev_frame_sequences(inserted)
            set_frame_sequences_view_ready(sequences)

            last_batch =
              sequences
              |> Enum.max_by(& &1.id, fn -> nil end)

            # credo:disable-for-next-line
            if last_batch do
              Instrumenter.set_latest_batch(last_batch.id, last_batch.l1_timestamp)
            end

            Publisher.broadcast(
              %{
                new_optimism_batches:
                  Enum.map(sequences, &FrameSequence.batch_by_internal_id(&1.id, include_blobs?: false))
              },
              :realtime
            )

            Helper.log_blocks_chunk_handling(
              chunk_start,
              chunk_end,
              start_block,
              end_block,
              "#{Enum.count(sequences)} batch(es) containing #{Enum.count(batches)} block(s).",
              :L1
            )

            {new_incomplete_channels, last_block_hash}
          else
            {incomplete_channels_acc, nil}
          end

        reorg_block = RollupReorgMonitorQueue.reorg_block_pop(__MODULE__)

        if !is_nil(reorg_block) && reorg_block > 0 do
          new_incomplete_channels = handle_l1_reorg(reorg_block, new_incomplete_channels)

          Optimism.set_last_block_hash(@empty_hash, @counter_type)

          {:halt, {if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end), new_incomplete_channels}}
        else
          Optimism.set_last_block_hash(last_block_hash, @counter_type)

          {:cont, {chunk_end, new_incomplete_channels}}
        end
      end)

    new_start_block = last_written_block + 1
    new_end_block = Helper.fetch_latest_l1_block_number(json_rpc_named_arguments)

    delay =
      if new_end_block == last_written_block do
        # there is no new block, so wait for some time to let the chain issue the new block
        max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
      else
        0
      end

    Process.send_after(self(), :continue, delay)

    {:noreply,
     %{
       state
       | start_block: new_start_block,
         end_block: new_end_block,
         incomplete_channels: new_incomplete_channels
     }}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @doc false
  def get_block_numbers_by_hashes([], _json_rpc_named_arguments_l2) do
    %{}
  end

  def get_block_numbers_by_hashes(hashes, json_rpc_named_arguments_l2) do
    query =
      from(
        b in Block,
        select: {b.hash, b.number},
        where: b.hash in ^hashes
      )

    number_by_hash =
      query
      |> Repo.all(timeout: :infinity)
      |> Enum.reduce(%{}, fn {hash, number}, acc ->
        Map.put(acc, hash.bytes, number)
      end)

    requests =
      hashes
      |> Enum.filter(fn hash -> is_nil(Map.get(number_by_hash, hash)) end)
      |> Enum.with_index()
      |> Enum.map(fn {hash, id} ->
        {:ok, hash} = Hash.Full.cast(hash)
        ByHash.request(%{hash: hash, id: id}, false)
      end)

    chunk_size = 50
    chunks_number = ceil(Enum.count(requests) / chunk_size)
    chunk_range = Range.new(0, chunks_number - 1, 1)

    chunk_range
    |> Enum.reduce([], fn current_chunk, acc ->
      {:ok, resp} =
        requests
        |> Enum.slice(chunk_size * current_chunk, chunk_size)
        |> json_rpc(json_rpc_named_arguments_l2)

      acc ++ resp
    end)
    |> Enum.map(fn %{result: result} -> result end)
    |> Enum.reduce(number_by_hash, fn block, acc ->
      if is_nil(block) do
        acc
      else
        block_number = quantity_to_integer(Map.get(block, "number"))
        "0x" <> hash = Map.get(block, "hash")
        {:ok, hash} = Base.decode16(hash, case: :lower)
        Map.put(acc, hash, block_number)
      end
    end)
  end

  defp get_block_hash_by_number(block_number, blocks_params) do
    block = Enum.find(blocks_params, %{hash: nil}, fn b -> b.number == block_number end)
    block.hash
  end

  defp get_block_timestamp_by_number(block_number, blocks_params) do
    block = Enum.find(blocks_params, %{timestamp: nil}, fn b -> b.number == block_number end)
    block.timestamp
  end

  # Determines the last saved L1 block number, the last saved transaction hash, and the transaction info for batches.
  #
  # Utilized to start fetching from a correct block number after reorg has occurred.
  #
  # ## Parameters
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #                               Used to get transaction info by its hash from the RPC node.
  #
  # ## Returns
  # - A tuple `{last_block_number, last_transaction_hash, last_transaction}` where
  #   `last_block_number` is the last block number found in the corresponding table (0 if not found),
  #   `last_transaction_hash` is the last transaction hash found in the corresponding table (nil if not found),
  #   `last_transaction` is the transaction info got from the RPC (nil if not found).
  @spec get_last_l1_item(EthereumJSONRPC.json_rpc_named_arguments()) :: {non_neg_integer(), binary() | nil, map() | nil}
  defp get_last_l1_item(json_rpc_named_arguments) do
    last_l1_block_number =
      Optimism.get_last_block_number_from_last_fetched_counter(json_rpc_named_arguments, @counter_type)

    if is_nil(last_l1_block_number) do
      result =
        Repo.one(
          from(
            tb in OptimismTransactionBatch,
            inner_join: fs in FrameSequence,
            on: fs.id == tb.frame_sequence_id,
            select: {fs.id, fs.l1_transaction_hashes},
            order_by: [desc: tb.l2_block_number],
            limit: 1
          )
        )

      with {:empty_hashes, false} <- {:empty_hashes, is_nil(result)},
           l1_transaction_hashes = elem(result, 1),
           last_l1_transaction_hash = List.last(l1_transaction_hashes),
           {:ok, last_l1_transaction} =
             Helper.get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
           {:empty_transaction, false, last_l1_transaction_hash} <-
             {:empty_transaction, is_nil(last_l1_transaction), last_l1_transaction_hash} do
        last_l1_block_number = quantity_to_integer(Map.get(last_l1_transaction, "blockNumber", 0))
        {last_l1_block_number, last_l1_transaction_hash, last_l1_transaction}
      else
        {:empty_hashes, true} ->
          {0, nil, nil}

        {:empty_transaction, true, last_l1_transaction_hash} ->
          Logger.error(
            "Cannot find last L1 transaction from RPC by its hash (#{last_l1_transaction_hash}). Probably, there was a reorg on L1 chain. Trying to check preceding frame sequence..."
          )

          id = elem(result, 0)

          Multi.new()
          |> Multi.delete_all(
            :delete_transaction_batches,
            from(tb in OptimismTransactionBatch, where: tb.frame_sequence_id == ^id)
          )
          |> Multi.delete_all(:delete_frame_sequence, from(fs in FrameSequence, where: fs.id == ^id))
          |> Repo.transaction()

          get_last_l1_item(json_rpc_named_arguments)
      end
    else
      {last_l1_block_number, nil, nil}
    end
  end

  defp get_transaction_batches(
         block_range,
         batch_inbox,
         batch_submitter,
         {genesis_block_l2, block_duration},
         incomplete_channels,
         {json_rpc_named_arguments, json_rpc_named_arguments_l2},
         blobs_api_url,
         retries_left
       ) do
    case fetch_blocks_by_range(block_range, json_rpc_named_arguments) do
      {:ok, %Blocks{transactions_params: transactions_params, blocks_params: blocks_params, errors: []}} ->
        last_block_hash =
          block_range
          |> Enum.max()
          |> get_block_hash_by_number(blocks_params)

        transactions_params
        |> transactions_filter(batch_submitter, batch_inbox)
        |> get_transaction_batches_inner(
          blocks_params,
          {genesis_block_l2, block_duration},
          incomplete_channels,
          json_rpc_named_arguments_l2,
          blobs_api_url
        )
        |> Tuple.append(last_block_hash)

      {_, message_or_errors} ->
        message =
          case message_or_errors do
            %Blocks{errors: errors} -> errors
            msg -> msg
          end

        retries_left = retries_left - 1

        error_message = "Cannot fetch blocks #{inspect(block_range)}. Error(s): #{inspect(message)}"

        if retries_left <= 0 do
          Logger.error(error_message)
          {:error, message}
        else
          Optimism.log_error_message_with_retry_sleep(error_message)

          get_transaction_batches(
            block_range,
            batch_inbox,
            batch_submitter,
            {genesis_block_l2, block_duration},
            incomplete_channels,
            {json_rpc_named_arguments, json_rpc_named_arguments_l2},
            blobs_api_url,
            retries_left
          )
        end
    end
  end

  defp eip4844_blobs_to_inputs(_transaction_hash, _blob_versioned_hashes, _block_timestamp, "", _chain_id_l1) do
    Logger.error(
      "Cannot read EIP-4844 blobs from the Blockscout Blobs API as the API URL is not defined. Please, check INDEXER_OPTIMISM_L1_BATCH_BLOCKSCOUT_BLOBS_API_URL env variable."
    )

    []
  end

  defp eip4844_blobs_to_inputs(
         transaction_hash,
         blob_versioned_hashes,
         block_timestamp,
         blobs_api_url,
         chain_id_l1
       ) do
    blob_versioned_hashes
    |> Enum.reduce([], fn blob_hash, inputs_acc ->
      with {:ok, response} <- Helper.http_get_request(blobs_api_url <> "/" <> blob_hash),
           blob_data = Map.get(response, "blob_data"),
           false <- is_nil(blob_data) do
        # read the data from Blockscout API
        decoded =
          blob_data
          |> hash_to_binary()
          |> OptimismTransactionBatch.decode_eip4844_blob()

        if is_nil(decoded) do
          Logger.warning("Cannot decode the blob #{blob_hash} taken from the Blockscout Blobs API.")

          inputs_acc
        else
          Logger.info(
            "The input for transaction #{transaction_hash} is taken from the Blockscout Blobs API. Blob hash: #{blob_hash}"
          )

          input = %{
            bytes: decoded,
            eip4844_blob_hash: blob_hash
          }

          [input | inputs_acc]
        end
      else
        _ ->
          # read the data from the fallback source (beacon node)
          eip4844_blobs_to_inputs_from_fallback(
            transaction_hash,
            blob_hash,
            block_timestamp,
            inputs_acc,
            chain_id_l1
          )
      end
    end)
    |> Enum.reverse()
  end

  defp eip4844_blobs_to_inputs_from_fallback(
         transaction_hash,
         blob_hash,
         block_timestamp,
         inputs_acc,
         chain_id_l1
       ) do
    blob = Helper.get_eip4844_blob_from_beacon_node(blob_hash, block_timestamp, chain_id_l1)

    with false <- is_nil(blob),
         decoded_blob_data = OptimismTransactionBatch.decode_eip4844_blob(blob),
         {:blob_data_invalid, false} <- {:blob_data_invalid, is_nil(decoded_blob_data)} do
      Logger.info(
        "The input for transaction #{transaction_hash} is taken from the Beacon Node. Blob hash: #{blob_hash}"
      )

      input = %{
        bytes: decoded_blob_data,
        eip4844_blob_hash: blob_hash
      }

      [input | inputs_acc]
    else
      true ->
        inputs_acc

      {:blob_data_invalid, true} ->
        Logger.warning("Cannot decode invalid blob #{blob_hash} taken from the Beacon Node.")
        inputs_acc
    end
  end

  # Gets Celestia blob data & metadata by L1 transaction input (encoding blob's height and commitment).
  # The data is read from the remote `da-indexer` service.
  #
  # ## Parameters
  # - `transaction_input`: The contents of transaction `input` field.
  # - `offset`: Offset (in bytes) within the `transaction_input` where blob's height is encoded.
  # - `transaction_hash`: The L1 transaction hash for logging purposes.
  # - `blobs_api_url`: The URL to `da-indexer` API.
  #
  # ## Returns
  # - A list with a map containing blob's data and metadata.
  # - An empty list in case of an error (`da-indexer` didn't respond, URL is not defined, or transaction input is incorrect).
  @spec celestia_blob_to_input(binary(), non_neg_integer(), String.t(), String.t()) :: [
          %{
            :bytes => binary(),
            :celestia_blob_metadata => %{
              :height => non_neg_integer(),
              :namespace => String.t(),
              :commitment => String.t()
            }
          }
        ]
  defp celestia_blob_to_input("0x" <> transaction_input, offset, transaction_hash, blobs_api_url) do
    transaction_input
    |> Base.decode16!(case: :mixed)
    |> celestia_blob_to_input(offset, transaction_hash, blobs_api_url)
  end

  defp celestia_blob_to_input(transaction_input, offset, _transaction_hash, blobs_api_url)
       when byte_size(transaction_input) == offset + 8 + 32 and blobs_api_url != "" do
    # 8 bytes after alt-da signature encode little-endian Celestia blob height
    height =
      transaction_input
      |> binary_part(offset, 8)
      |> :binary.decode_unsigned(:little)

    # the next 32 bytes contain the commitment
    commitment = binary_part(transaction_input, offset + 8, 32)
    commitment_string = Base.encode16(commitment, case: :lower)

    url = blobs_api_url <> "?height=#{height}&commitment=" <> commitment_string

    with {:ok, response} <- Helper.http_get_request(url),
         namespace = Map.get(response, "namespace"),
         data = Map.get(response, "data"),
         true <- !is_nil(namespace) and !is_nil(data) do
      data_decoded = Base.decode64!(data)

      [
        %{
          bytes: data_decoded,
          celestia_blob_metadata: %{
            height: height,
            namespace: "0x" <> namespace,
            commitment: "0x" <> commitment_string
          }
        }
      ]
    else
      false ->
        Logger.error("Cannot read namespace or data from Celestia Blobs API response for the request #{url}")

        []

      _ ->
        Logger.error("Cannot read a response from Celestia Blobs API for the request #{url}")
        []
    end
  end

  defp celestia_blob_to_input(_transaction_input, _offset, transaction_hash, blobs_api_url) when blobs_api_url != "" do
    Logger.error("L1 transaction with Celestia commitment has incorrect input length. Tx hash: #{transaction_hash}")

    []
  end

  defp celestia_blob_to_input(_transaction_input, _offset, _transaction_hash, "") do
    Logger.error(
      "Cannot read Celestia blobs from the server as the API URL is not defined. Please, check INDEXER_OPTIMISM_L1_BATCH_CELESTIA_BLOBS_API_URL env variable."
    )

    []
  end

  defp get_transaction_batches_inner(
         transactions_filtered,
         blocks_params,
         {genesis_block_l2, block_duration},
         incomplete_channels,
         json_rpc_named_arguments_l2,
         {eip4844_blobs_api_url, celestia_blobs_api_url, chain_id_l1}
       ) do
    transactions_filtered
    |> Enum.reduce({:ok, incomplete_channels, [], [], []}, fn transaction,
                                                              {_, incomplete_channels_acc, batches_acc, sequences_acc,
                                                               blobs_acc} ->
      inputs =
        cond do
          transaction.type == 3 ->
            # this is EIP-4844 transaction, so we get the inputs from the blobs
            block_timestamp = get_block_timestamp_by_number(transaction.block_number, blocks_params)

            eip4844_blobs_to_inputs(
              transaction.hash,
              transaction.blob_versioned_hashes,
              block_timestamp,
              eip4844_blobs_api_url,
              chain_id_l1
            )

          commitment_alt_da_signature(transaction.input) == 0x01010C ->
            # this is Celestia DA transaction, so we get the data from Celestia blob
            celestia_blob_to_input(transaction.input, 3, transaction.hash, celestia_blobs_api_url)

          first_byte(transaction.input) == 0xCE ->
            # backward compatibility with OP Celestia Raspberry
            celestia_blob_to_input(transaction.input, 1, transaction.hash, celestia_blobs_api_url)

          true ->
            # this is calldata transaction, so the data is in the transaction input
            [%{bytes: transaction.input}]
        end

      Enum.reduce(
        inputs,
        {:ok, incomplete_channels_acc, batches_acc, sequences_acc, blobs_acc},
        fn input, {_, new_incomplete_channels_acc, new_batches_acc, new_sequences_acc, new_blobs_acc} ->
          handle_input(
            input,
            transaction,
            blocks_params,
            new_incomplete_channels_acc,
            {new_batches_acc, new_sequences_acc, new_blobs_acc},
            {genesis_block_l2, block_duration},
            json_rpc_named_arguments_l2
          )
        end
      )
    end)
  end

  defp handle_input(
         input,
         transaction,
         blocks_params,
         incomplete_channels_acc,
         {batches_acc, sequences_acc, blobs_acc},
         {genesis_block_l2, block_duration},
         json_rpc_named_arguments_l2
       ) do
    frame = input_to_frame(input.bytes)

    if frame == :invalid_frame do
      Logger.warning("The frame in transaction #{transaction.hash} is invalid.")
      raise "Invalid frame"
    end

    block_timestamp = get_block_timestamp_by_number(transaction.block_number, blocks_params)

    channel = Map.get(incomplete_channels_acc, frame.channel_id, %{frames: %{}})

    channel_frames =
      Map.put(channel.frames, frame.number, %{
        data: frame.data,
        is_last: frame.is_last,
        block_number: transaction.block_number,
        block_timestamp: block_timestamp,
        transaction_hash: transaction.hash,
        eip4844_blob_hash: Map.get(input, :eip4844_blob_hash),
        celestia_blob_metadata: Map.get(input, :celestia_blob_metadata)
      })

    l1_timestamp =
      if frame.is_last do
        block_timestamp
      else
        Map.get(channel, :l1_timestamp)
      end

    channel_updated =
      channel
      |> Map.put_new(:id, frame.channel_id)
      |> Map.put(:frames, channel_frames)
      |> Map.put(:timestamp, DateTime.utc_now())
      |> Map.put(:l1_timestamp, l1_timestamp)

    if channel_complete?(channel_updated) do
      handle_channel(
        channel_updated,
        incomplete_channels_acc,
        batches_acc,
        sequences_acc,
        blobs_acc,
        {genesis_block_l2, block_duration},
        json_rpc_named_arguments_l2
      )
    else
      {:ok, Map.put(incomplete_channels_acc, frame.channel_id, channel_updated), batches_acc, sequences_acc, blobs_acc}
    end
  rescue
    e ->
      Logger.warning("Exception thrown: #{inspect(e)}")
      {:ok, incomplete_channels_acc, batches_acc, sequences_acc, blobs_acc}
  end

  defp handle_channel(
         channel,
         incomplete_channels_acc,
         batches_acc,
         sequences_acc,
         blobs_acc,
         {genesis_block_l2, block_duration},
         json_rpc_named_arguments_l2
       ) do
    frame_sequence_last = List.first(sequences_acc)
    frame_sequence_id = next_frame_sequence_id(frame_sequence_last)

    {bytes, l1_transaction_hashes, new_blobs_acc} =
      0..(Enum.count(channel.frames) - 1)
      |> Enum.reduce({<<>>, [], blobs_acc}, fn frame_number, {bytes_acc, transaction_hashes_acc, new_blobs_acc} ->
        frame = Map.get(channel.frames, frame_number)

        next_blob_id = next_blob_id(List.last(new_blobs_acc))

        new_blobs_acc =
          cond do
            !is_nil(Map.get(frame, :eip4844_blob_hash)) ->
              # credo:disable-for-next-line /Credo.Check.Refactor.AppendSingleItem/
              new_blobs_acc ++
                [
                  %{
                    id: next_blob_id,
                    key:
                      Base.decode16!(String.trim_leading(frame.eip4844_blob_hash, "0x"),
                        case: :mixed
                      ),
                    type: :eip4844,
                    metadata: %{hash: frame.eip4844_blob_hash},
                    l1_transaction_hash: frame.transaction_hash,
                    l1_timestamp: frame.block_timestamp,
                    frame_sequence_id: frame_sequence_id
                  }
                ]

            !is_nil(Map.get(frame, :celestia_blob_metadata)) ->
              height = :binary.encode_unsigned(frame.celestia_blob_metadata.height)

              commitment =
                Base.decode16!(String.trim_leading(frame.celestia_blob_metadata.commitment, "0x"),
                  case: :mixed
                )

              # credo:disable-for-next-line /Credo.Check.Refactor.AppendSingleItem/
              new_blobs_acc ++
                [
                  %{
                    id: next_blob_id,
                    key: :crypto.hash(:sha256, height <> commitment),
                    type: :celestia,
                    metadata: frame.celestia_blob_metadata,
                    l1_transaction_hash: frame.transaction_hash,
                    l1_timestamp: frame.block_timestamp,
                    frame_sequence_id: frame_sequence_id
                  }
                ]

            true ->
              new_blobs_acc
          end

        {bytes_acc <> frame.data, [frame.transaction_hash | transaction_hashes_acc], new_blobs_acc}
      end)

    batches_parsed =
      parse_frame_sequence(
        bytes,
        frame_sequence_id,
        channel.l1_timestamp,
        {genesis_block_l2, block_duration},
        json_rpc_named_arguments_l2
      )

    if batches_parsed == :error do
      Logger.error("Cannot parse frame sequence from these L1 transaction(s): #{inspect(l1_transaction_hashes)}")
    end

    sequence = %{
      id: frame_sequence_id,
      l1_transaction_hashes: Enum.uniq(Enum.reverse(l1_transaction_hashes)),
      l1_timestamp: channel.l1_timestamp
    }

    new_incomplete_channels_acc =
      incomplete_channels_acc
      |> Map.delete(channel.id)
      |> remove_expired_channels()

    if batches_parsed == :error or Enum.empty?(batches_parsed) do
      {:ok, new_incomplete_channels_acc, batches_acc, sequences_acc, blobs_acc}
    else
      {:ok, new_incomplete_channels_acc, batches_acc ++ batches_parsed, [sequence | sequences_acc], new_blobs_acc}
    end
  end

  defp handle_l1_reorg(reorg_block, incomplete_channels) do
    incomplete_channels
    |> Enum.reduce(incomplete_channels, fn {channel_id, %{frames: frames} = channel}, acc ->
      updated_frames =
        frames
        |> Enum.filter(fn {_frame_number, %{block_number: block_number}} ->
          block_number < reorg_block
        end)
        |> Enum.into(%{})

      if Enum.empty?(updated_frames) do
        Map.delete(acc, channel_id)
      else
        Map.put(acc, channel_id, Map.put(channel, :frames, updated_frames))
      end
    end)
  end

  @doc """
    Removes rows from op_transaction_batches and op_frame_sequences tables written beginning from the L2 reorg block.
  """
  @spec handle_l2_reorg(non_neg_integer()) :: any()
  def handle_l2_reorg(reorg_block) do
    frame_sequence_ids =
      Repo.all(
        from(
          tb in OptimismTransactionBatch,
          select: tb.frame_sequence_id,
          where: tb.l2_block_number >= ^reorg_block
        ),
        timeout: :infinity
      )

    {deleted_count, _} =
      Repo.delete_all(from(tb in OptimismTransactionBatch, where: tb.l2_block_number >= ^reorg_block))

    Repo.delete_all(from(fs in FrameSequence, where: fs.id in ^frame_sequence_ids))

    if deleted_count > 0 do
      Logger.warning(
        "As L2 reorg was detected, all rows with l2_block_number >= #{reorg_block} were removed from the op_transaction_batches table. Number of removed rows: #{deleted_count}."
      )
    end
  end

  @doc """
    Returns L1 RPC URL for this module.
  """
  @spec l1_rpc_url() :: binary() | nil
  def l1_rpc_url do
    Optimism.l1_rpc_url()
  end

  @doc """
    Determines if `Indexer.Fetcher.RollupL1ReorgMonitor` module must be up
    before this fetcher starts.

    ## Returns
    - `true` if the reorg monitor must be active, `false` otherwise.
  """
  @spec requires_l1_reorg_monitor?() :: boolean()
  def requires_l1_reorg_monitor? do
    Optimism.requires_l1_reorg_monitor?()
  end

  defp channel_complete?(channel) do
    last_frame_number =
      channel.frames
      |> Map.keys()
      |> Enum.max()

    Map.get(channel.frames, last_frame_number).is_last and
      last_frame_number == Enum.count(channel.frames) - 1
  end

  defp remove_expired_channels(channels_map) do
    now = DateTime.utc_now()

    Enum.reduce(channels_map, channels_map, fn {channel_id, %{timestamp: timestamp}}, channels_acc ->
      if DateTime.diff(now, timestamp) >= 86400 do
        Map.delete(channels_acc, channel_id)
      else
        channels_acc
      end
    end)
  end

  defp input_to_frame("0x" <> input) do
    input
    |> Base.decode16!(case: :mixed)
    |> input_to_frame()
  end

  defp input_to_frame(input_binary) do
    # the structure of the input is as follows:
    #
    # input = derivation_version ++ channel_id ++ frame_number ++ frame_data_length ++ frame_data ++ is_last
    #
    # derivation_version = uint8
    # channel_id         = bytes16
    # frame_number       = uint16
    # frame_data_length  = uint32
    # frame_data         = bytes
    # is_last            = bool (uint8)

    derivation_version_length = 1
    channel_id_length = 16
    frame_number_size = 2
    frame_data_length_size = 4
    is_last_size = 1

    # the first byte must be zero
    derivation_version = first_byte(input_binary)

    if derivation_version != 0x00 do
      Logger.warning("Derivation version #{derivation_version} is not supported. The frame will be ignored.")

      raise "Unsupported derivation version"
    end

    # channel id has 16 bytes
    channel_id = binary_part(input_binary, derivation_version_length, channel_id_length)

    # frame number consists of 2 bytes
    frame_number_offset = derivation_version_length + channel_id_length

    frame_number = :binary.decode_unsigned(binary_part(input_binary, frame_number_offset, frame_number_size))

    # frame data length consists of 4 bytes
    frame_data_length_offset = frame_number_offset + frame_number_size

    frame_data_length =
      :binary.decode_unsigned(binary_part(input_binary, frame_data_length_offset, frame_data_length_size))

    input_length_must_be =
      derivation_version_length + channel_id_length + frame_number_size + frame_data_length_size +
        frame_data_length +
        is_last_size

    input_length_current = byte_size(input_binary)

    if input_length_current == input_length_must_be do
      # frame data is a byte array of frame_data_length size
      frame_data_offset = frame_data_length_offset + frame_data_length_size
      frame_data = binary_part(input_binary, frame_data_offset, frame_data_length)

      # is_last is 1-byte item
      is_last_offset = frame_data_offset + frame_data_length

      is_last = :binary.decode_unsigned(binary_part(input_binary, is_last_offset, is_last_size)) > 0

      %{number: frame_number, data: frame_data, is_last: is_last, channel_id: channel_id}
    else
      # workaround to remove a leading extra byte
      # for example, the case for Base Goerli batch L1 transaction: https://goerli.etherscan.io/tx/0xa43fa9da683a6157a114e3175a625b5aed85d8c573aae226768c58a924a17be0
      input_to_frame("0x" <> Base.encode16(binary_part(input_binary, 1, input_length_current - 1)))
    end
  rescue
    _ -> :invalid_frame
  end

  defp next_blob_id(last_known_blob) when is_nil(last_known_blob) do
    last_known_id =
      Repo.one(
        from(
          fsb in FrameSequenceBlob,
          select: fsb.id,
          order_by: [desc: fsb.id],
          limit: 1
        )
      )

    if is_nil(last_known_id) do
      1
    else
      last_known_id + 1
    end
  end

  defp next_blob_id(last_known_blob) do
    last_known_blob.id + 1
  end

  defp next_frame_sequence_id(last_known_sequence) when is_nil(last_known_sequence) do
    last_known_id =
      Repo.one(
        from(
          fs in FrameSequence,
          select: fs.id,
          order_by: [desc: fs.id],
          limit: 1
        )
      )

    if is_nil(last_known_id) do
      1
    else
      last_known_id + 1
    end
  end

  defp next_frame_sequence_id(last_known_sequence) do
    last_known_sequence.id + 1
  end

  defp parse_frame_sequence(
         bytes,
         id,
         l1_timestamp,
         {genesis_block_l2, block_duration},
         json_rpc_named_arguments_l2
       ) do
    uncompressed_bytes =
      if first_byte(bytes) == @compressor_brotli do
        bytes
        |> binary_part(1, byte_size(bytes) - 1)
        |> ExBrotli.decompress!()
      else
        zlib_decompress(bytes)
      end

    batches =
      Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), {uncompressed_bytes, []}, fn _i, {remainder, batch_acc} ->
        try do
          {decoded, new_remainder} = ExRLP.decode(remainder, stream: true)

          <<version::size(8), content::binary>> = decoded

          new_batch_acc =
            cond do
              version == 0 ->
                handle_v0_batch(content, id, l1_timestamp, batch_acc)

              version <= 2 ->
                # parsing the span batch
                handle_v1_batch(content, id, l1_timestamp, genesis_block_l2, block_duration, batch_acc)

              true ->
                Logger.error("Unsupported batch version ##{version}")
                :error
            end

          if byte_size(new_remainder) > 0 and new_batch_acc != :error do
            {:cont, {new_remainder, new_batch_acc}}
          else
            {:halt, new_batch_acc}
          end
        rescue
          _ -> {:halt, :error}
        end
      end)

    if batches == :error do
      :error
    else
      batches = Enum.reverse(batches)

      numbers_by_hashes =
        batches
        |> Stream.filter(&Map.has_key?(&1, :parent_hash))
        |> Enum.map(fn batch -> batch.parent_hash end)
        |> get_block_numbers_by_hashes(json_rpc_named_arguments_l2)

      Enum.map(batches, &parent_hash_to_l2_block_number(&1, numbers_by_hashes))
    end
  end

  defp handle_v0_batch(content, frame_sequence_id, l1_timestamp, batch_acc) do
    content_decoded = ExRLP.decode(content)

    batch = %{
      parent_hash: Enum.at(content_decoded, 0),
      frame_sequence_id: frame_sequence_id,
      l1_timestamp: l1_timestamp
    }

    [batch | batch_acc]
  end

  defp handle_v1_batch(content, frame_sequence_id, l1_timestamp, genesis_block_l2, block_duration, batch_acc) do
    {rel_timestamp, content_remainder} = LEB128.decode(content)

    # skip l1_origin_num
    {_l1_origin_num, checks_and_payload} = LEB128.decode(content_remainder)

    # skip `parent_check` and `l1_origin_check` fields (20 bytes each)
    # and read the block count
    {block_count, _} =
      checks_and_payload
      |> binary_part(40, byte_size(checks_and_payload) - 40)
      |> LEB128.decode()

    # the first and last L2 blocks in the span
    span_start = div(rel_timestamp, block_duration) + genesis_block_l2
    span_end = span_start + block_count - 1

    cond do
      rem(rel_timestamp, block_duration) != 0 ->
        Logger.error("rel_timestamp is not divisible by #{block_duration}. We ignore the span batch.")

        batch_acc

      block_count <= 0 ->
        Logger.error("Empty span batch found. We ignore it.")
        batch_acc

      true ->
        span_start..span_end
        |> Enum.reduce(batch_acc, fn l2_block_number, batch_acc ->
          [
            %{
              l2_block_number: l2_block_number,
              frame_sequence_id: frame_sequence_id,
              l1_timestamp: l1_timestamp
            }
            | batch_acc
          ]
        end)
    end
  end

  defp parent_hash_to_l2_block_number(batch, numbers_by_hashes) do
    if Map.has_key?(batch, :parent_hash) do
      number = Map.get(numbers_by_hashes, batch.parent_hash)

      batch
      |> Map.put(:l2_block_number, number + 1)
      |> Map.delete(:parent_hash)
    else
      batch
    end
  end

  defp remove_duplicates(batches, sequences, blobs) do
    unique_batches =
      batches
      |> Enum.sort(fn b1, b2 ->
        b1.l2_block_number < b2.l2_block_number or
          (b1.l2_block_number == b2.l2_block_number and b1.l1_timestamp < b2.l1_timestamp)
      end)
      |> Enum.reduce(%{}, fn b, acc ->
        Map.put(acc, b.l2_block_number, Map.delete(b, :l1_timestamp))
      end)
      |> Map.values()

    unique_sequences =
      sequences
      |> Enum.reverse()
      |> Enum.filter(fn seq ->
        Enum.any?(unique_batches, fn batch -> batch.frame_sequence_id == seq.id end)
      end)

    unique_blobs =
      blobs
      |> Enum.reduce(%{}, fn b, acc ->
        prev_id = Map.get(acc, b.key, %{id: 0}).id

        if prev_id < b.id do
          Map.put(acc, b.key, b)
        else
          acc
        end
      end)
      |> Map.values()
      |> Enum.filter(fn b ->
        Enum.any?(unique_sequences, fn sec -> sec.id == b.frame_sequence_id end)
      end)

    {unique_batches, unique_sequences, unique_blobs}
  end

  defp remove_prev_frame_sequences(inserted) do
    ids =
      inserted
      |> Map.get(:insert_transaction_batches, [])
      |> Enum.map(fn tb -> tb.frame_sequence_id_prev end)
      |> Enum.uniq()
      |> Enum.filter(fn id -> id > 0 end)

    try do
      Repo.delete_all(from(fs in FrameSequence, where: fs.id in ^ids))
    rescue
      # we need to ignore `foreign_key_violation` exception when deleting the rows
      # because there can be a case when the chain partially replaces the frame sequence
      # (e.g. Unichain Private Testnet), and so some rows in `op_transaction_batches` table
      # can still reference to the `op_frame_sequences` table
      _ -> nil
    end
  end

  defp set_frame_sequences_view_ready(sequences) do
    sequence_ids = Enum.map(sequences, fn s -> s.id end)

    Repo.update_all(
      from(fs in FrameSequence, where: fs.id in ^sequence_ids),
      set: [view_ready: true]
    )
  end

  defp transactions_filter(transactions_params, batch_submitter, batch_inbox) do
    transactions_params
    |> Enum.filter(fn t ->
      from_address_hash = Map.get(t, :from_address_hash)
      to_address_hash = Map.get(t, :to_address_hash)

      if is_nil(from_address_hash) or is_nil(to_address_hash) do
        false
      else
        String.downcase(from_address_hash) == batch_submitter and
          String.downcase(to_address_hash) == batch_inbox
      end
    end)
    |> Enum.sort(fn t1, t2 ->
      {t1.block_number, t1.index} < {t2.block_number, t2.index}
    end)
  end

  # Reads some public getters of SystemConfig contract and returns retrieved values.
  # Gets the number of a start block (from which this fetcher should start),
  # the inbox address, and the batcher (batch submitter) address.
  #
  # If SystemConfig has obsolete implementation, the values are fallen back from the corresponding
  # env variables (INDEXER_OPTIMISM_L1_START_BLOCK, INDEXER_OPTIMISM_L1_BATCH_INBOX, INDEXER_OPTIMISM_L1_BATCH_SUBMITTER).
  #
  # ## Parameters
  # - `contract_address`: An address of SystemConfig contract.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - A tuple: {start_block, inbox, submitter}.
  # - `nil` in case of error.
  @spec read_system_config(String.t(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          {non_neg_integer(), String.t(), String.t()} | nil
  defp read_system_config(contract_address, json_rpc_named_arguments) do
    requests = [
      # startBlock() public getter
      Contract.eth_call_request("0x48cd4cb1", contract_address, 0, nil, nil),
      # batchInbox() public getter
      Contract.eth_call_request("0xdac6e63a", contract_address, 1, nil, nil),
      # batcherHash() public getter
      Contract.eth_call_request("0xe81b2c6d", contract_address, 2, nil, nil)
    ]

    error_message = &"Cannot call public getters of SystemConfig. Error: #{inspect(&1)}"

    env = Application.get_all_env(:indexer)[__MODULE__]
    fallback_start_block = Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism][:start_block_l1]

    {start_block, batch_inbox, batch_submitter} =
      case Helper.repeated_call(
             &json_rpc/2,
             [requests, json_rpc_named_arguments],
             error_message,
             Helper.finite_retries_number()
           ) do
        {:ok, responses} ->
          start_block =
            responses
            |> Enum.at(0)
            |> Map.get(:result, fallback_start_block)
            |> quantity_to_integer()

          inbox_result = Map.get(Enum.at(responses, 1), :result)
          submitter_result = Map.get(Enum.at(responses, 2), :result)

          {batch_inbox, batch_submitter} =
            with {:nil_result, true, _, _} <-
                   {:nil_result, is_nil(inbox_result) or is_nil(submitter_result), inbox_result, submitter_result},
                 {:fallback_defined, true} <-
                   {:fallback_defined,
                    Helper.address_correct?(env[:inbox]) and Helper.address_correct?(env[:submitter])} do
              {env[:inbox], env[:submitter]}
            else
              {:nil_result, false, inbox, submitter} ->
                "0x000000000000000000000000" <> batch_inbox = inbox
                "0x000000000000000000000000" <> batch_submitter = submitter
                {"0x" <> batch_inbox, "0x" <> batch_submitter}

              {:fallback_defined, false} ->
                {nil, nil}
            end

          {start_block, batch_inbox, batch_submitter}

        _ ->
          {fallback_start_block, env[:inbox], env[:submitter]}
      end

    if !is_nil(start_block) and Helper.address_correct?(batch_inbox) and Helper.address_correct?(batch_submitter) do
      {start_block, String.downcase(batch_inbox), String.downcase(batch_submitter)}
    end
  end

  # Retrieves Alt-DA signature from L1 transaction input as described in
  # https://github.com/ethereum-optimism/specs/blob/main/specs/experimental/alt-da.md#example-commitments
  #
  # ## Parameters
  # - `transaction_input`: The contents of transaction `input` field.
  #
  # ## Returns
  # - An integer encoding the signature.
  # - `nil` if the input doesn't contain Alt-DA signature.
  @spec commitment_alt_da_signature(binary()) :: non_neg_integer() | nil
  defp commitment_alt_da_signature("0x" <> transaction_input) do
    transaction_input
    |> Base.decode16!(case: :mixed)
    |> commitment_alt_da_signature()
  end

  defp commitment_alt_da_signature(<<0, _rest::binary>>), do: 0x00
  defp commitment_alt_da_signature(<<1, 0, _rest::binary>>), do: 0x0100

  defp commitment_alt_da_signature(<<1, 1, da_layer_byte::size(8), _rest::binary>>),
    do: :binary.decode_unsigned(<<0x01, 0x01, da_layer_byte>>)

  defp commitment_alt_da_signature(_), do: nil

  defp first_byte("0x" <> transaction_input) do
    transaction_input
    |> Base.decode16!(case: :mixed)
    |> first_byte()
  end

  defp first_byte(<<first_byte::size(8), _rest::binary>>) do
    first_byte
  end

  defp first_byte(_transaction_input) do
    nil
  end

  defp zlib_decompress(bytes) do
    z = :zlib.open()
    :zlib.inflateInit(z)

    uncompressed_bytes =
      try do
        zlib_inflate(z, bytes)
      rescue
        _ -> <<>>
      end

    try do
      :zlib.inflateEnd(z)
    rescue
      _ -> nil
    end

    :zlib.close(z)

    uncompressed_bytes
  end

  defp zlib_inflate_handler(z, {:continue, [uncompressed_bytes]}, acc) do
    zlib_inflate(z, [], acc <> uncompressed_bytes)
  end

  defp zlib_inflate_handler(_z, {:finished, [uncompressed_bytes]}, acc) do
    acc <> uncompressed_bytes
  end

  defp zlib_inflate_handler(_z, {:finished, []}, acc) do
    acc
  end

  defp zlib_inflate(z, compressed_bytes, acc \\ <<>>) do
    result = :zlib.safeInflate(z, compressed_bytes)
    zlib_inflate_handler(z, result, acc)
  end
end
