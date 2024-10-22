defmodule Indexer.Fetcher.Scroll.Batch do
  @moduledoc """
  The module for scanning Scroll RPC node on L1 for the batch logs (events), parsing them,
  and importing to the database (into the `scroll_batches` and `scroll_batch_bundles` tables).

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

  alias ABI.{FunctionSelector, TypeDecoder}
  alias EthereumJSONRPC.Logs
  alias Explorer.Chain.Block.Range, as: BlockRange
  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Explorer.Chain.Scroll.{Batch, BatchBundle, Reader}
  alias Explorer.{Chain, Repo}
  alias Indexer.Fetcher.{RollupL1ReorgMonitor, Scroll}
  alias Indexer.Helper

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
         {:reorg_monitor_started, true} <- {:reorg_monitor_started, !is_nil(Process.whereis(RollupL1ReorgMonitor))},
         rpc = l1_rpc_url(),
         {:rpc_undefined, false} <- {:rpc_undefined, is_nil(rpc)},
         {:scroll_chain_contract_address_is_valid, true} <-
           {:scroll_chain_contract_address_is_valid, Helper.address_correct?(env[:scroll_chain_contract])},
         start_block = env[:start_block],
         false <- is_nil(start_block),
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
         {:l1_transaction_not_found, false} <-
           {:l1_transaction_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_transaction)} do
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         block_check_interval: block_check_interval,
         scroll_chain_contract: env[:scroll_chain_contract],
         json_rpc_named_arguments: json_rpc_named_arguments,
         end_block: safe_block,
         start_block: max(start_block, last_l1_block_number),
         eth_get_logs_range_size: Application.get_all_env(:indexer)[Indexer.Fetcher.Scroll][:eth_get_logs_range_size]
       }}
    else
      {:start_block_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, %{}}

      {:reorg_monitor_started, false} ->
        Logger.error("Cannot start this process as Indexer.Fetcher.RollupL1ReorgMonitor is not started.")
        {:stop, :normal, %{}}

      {:rpc_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, %{}}

      {:scroll_chain_contract_address_is_valid, false} ->
        Logger.error("L1 ScrollChain contract address is invalid or not defined.")
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
          eth_get_logs_range_size: eth_get_logs_range_size
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

          {batches, bundles} =
            {chunk_start, chunk_end}
            |> get_logs_all(scroll_chain_contract, json_rpc_named_arguments)
            |> prepare_items(json_rpc_named_arguments)

          import_items(batches, bundles)

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
    Scroll.l1_rpc_url()
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

  defp get_transaction_input_by_hash(blocks, transaction_hashes) do
    Enum.reduce(blocks, %{}, fn block, acc ->
      block
      |> Map.get("transactions", [])
      |> Enum.filter(fn tx ->
        Enum.member?(transaction_hashes, tx["hash"])
      end)
      |> Enum.map(fn tx ->
        {tx["hash"], tx["input"]}
      end)
      |> Enum.into(%{})
      |> Map.merge(acc)
    end)
  end

  defp input_to_l2_block_range(input) do
    chunks =
      case input do
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
      end

    {:ok, l2_block_range} =
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

    l2_block_range
  end

  defp import_items(batches, bundles) do
    start_by_final_batch_number =
      bundles
      |> Enum.reduce(%{}, fn bundle, acc ->
        Map.put(acc, bundle.final_batch_number, bundle.start_batch_number)
      end)

    {:ok, inserts} =
      Chain.import(%{
        scroll_batch_bundles: %{params: Enum.map(bundles, &Map.delete(&1, :start_batch_number))},
        scroll_batches: %{params: batches},
        timeout: :infinity
      })

    inserts
    |> Map.get(:insert_scroll_batch_bundles, [])
    |> Enum.each(fn bundle ->
      start_batch_number = start_by_final_batch_number[bundle.final_batch_number]

      Repo.update_all(
        from(b in Batch, where: b.number >= ^start_batch_number and b.number <= ^bundle.final_batch_number),
        set: [bundle_id: bundle.id]
      )
    end)
  end

  defp prepare_items(events, json_rpc_named_arguments) do
    blocks = Helper.get_blocks_by_events(events, json_rpc_named_arguments, Helper.infinite_retries_number(), true)

    commit_transaction_hashes =
      events
      |> Enum.reduce([], fn event, acc ->
        if event.first_topic == @commit_batch_event do
          [event.transaction_hash | acc]
        else
          acc
        end
      end)

    commit_transaction_input_by_hash = get_transaction_input_by_hash(blocks, commit_transaction_hashes)

    timestamps =
      blocks
      |> Enum.reduce(%{}, fn block, acc ->
        block_number = quantity_to_integer(Map.get(block, "number"))
        {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
        Map.put(acc, block_number, timestamp)
      end)

    prev_final_batch_number = Reader.last_final_batch_number()

    {_, batches, bundles} =
      events
      |> Enum.reduce({prev_final_batch_number, [], []}, fn event,
                                                           {prev_final_batch_number_acc, batches_acc, bundles_acc} ->
        batch_number = quantity_to_integer(event.second_topic)

        if event.first_topic == @commit_batch_event do
          commit_block_number = quantity_to_integer(event.block_number)

          # credo:disable-for-lines:2 Credo.Check.Refactor.Nesting
          l2_block_range =
            if batch_number == 0 do
              {:ok, range} = BlockRange.cast("[0,0]")
              range
            else
              commit_transaction_input_by_hash
              |> Map.get(event.transaction_hash)
              |> input_to_l2_block_range()
            end

          new_batches_acc = [
            %{
              number: batch_number,
              commit_transaction_hash: event.transaction_hash,
              commit_block_number: commit_block_number,
              commit_timestamp: Map.get(timestamps, commit_block_number),
              l2_block_range: l2_block_range
            }
            | batches_acc
          ]

          {prev_final_batch_number_acc, new_batches_acc, bundles_acc}
        else
          finalize_block_number = quantity_to_integer(event.block_number)

          new_bundles_acc = [
            %{
              start_batch_number: prev_final_batch_number_acc + 1,
              final_batch_number: batch_number,
              finalize_transaction_hash: event.transaction_hash,
              finalize_block_number: finalize_block_number,
              finalize_timestamp: Map.get(timestamps, finalize_block_number)
            }
            | bundles_acc
          ]

          {batch_number, batches_acc, new_bundles_acc}
        end
      end)

    {Enum.reverse(batches), Enum.reverse(bundles)}
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

    {deleted_batches_count, _} = Repo.delete_all(from(b in Batch, where: b.bundle_id in ^bundle_ids))

    {deleted_bundles_count, _} =
      Repo.delete_all(from(bb in BatchBundle, where: bb.id in ^bundle_ids or bb.finalize_block_number >= ^reorg_block))

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
