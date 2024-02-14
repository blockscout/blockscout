defmodule Indexer.Fetcher.Arbitrum.TrackingBatchesStatuses do
  @moduledoc """
  TBD
  """

  use GenServer
  use Indexer.Fetcher

  alias ABI.{FunctionSelector, TypeDecoder}

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  import Indexer.Fetcher.Arbitrum.Utils.Helper, only: [increase_duration: 2, list_to_chunks: 2]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum.Reader

  require Logger

  # keccak256("SequencerBatchDelivered(uint256,bytes32,bytes32,bytes32,uint256,(uint64,uint64,uint64,uint64),uint8)")
  @message_sequencer_batch_delivered "0x7394f4a19a13c7b92b5bb71033245305946ef78452f7b4986ac1390b5df4ebd7"

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
    Logger.metadata(fetcher: :arbitrum_batches_tracker)

    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    l1_rpc = config_common[:l1_rpc]
    l1_rpc_block_range = config_common[:l1_rpc_block_range]
    l1_rollup_address = config_common[:l1_rollup_address]
    l1_start_block = config_common[:l1_start_block]
    l1_rpc_chunk_size = config_common[:l1_rpc_chunk_size]

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]
    messages_to_blocks_shift = config_tracker[:messages_to_blocks_shift]
    track_l1_tx_finalization = config_tracker[:track_l1_tx_finalization]

    Process.send(self(), :init_worker, [])

    {:ok,
     %{
       config: %{
         json_l2_rpc_named_arguments: args[:json_rpc_named_arguments],
         json_l1_rpc_named_arguments: IndexerHelper.build_json_rpc_named_arguments(l1_rpc),
         l1_rpc_chunk_size: l1_rpc_chunk_size,
         recheck_interval: recheck_interval,
         l1_rpc_block_range: l1_rpc_block_range,
         l1_rollup_address: l1_rollup_address,
         l1_start_block: l1_start_block,
         messages_to_blocks_shift: messages_to_blocks_shift,
         track_l1_tx_finalization: track_l1_tx_finalization
       },
       data: %{}
     }}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # TBD
  @impl GenServer
  def handle_info(:init_worker, state) do
    %{outbox: outbox_address, sequencer_inbox: sequencer_inbox_address} =
      Rpc.get_contracts_for_rollup(
        state.config.l1_rollup_address,
        :inbox_outbox,
        state.config.json_l1_rpc_named_arguments
      )

    new_batches_start_block = Db.l1_block_of_latest_committed_batch(state.config.l1_start_block)

    new_confirmations_start_block = state.config.l1_start_block

    Process.send(self(), :check_new_batches, [])

    new_state =
      state
      |> Map.put(
        :config,
        Map.merge(state.config, %{
          l1_outbox_address: outbox_address,
          l1_sequencer_inbox_address: sequencer_inbox_address
        })
      )
      |> Map.put(
        :data,
        Map.merge(state.data, %{
          new_batches_start_block: new_batches_start_block,
          new_confirmations_start_block: new_confirmations_start_block
        })
      )

    {:noreply, new_state}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_new_batches, state) do
    {handle_duration, {:ok, end_block}} =
      :timer.tc(&discover_new_batches/1, [
        state
      ])

    # {handle_duration, _} =
    #   :timer.tc(&nothing_to_do/1, [
    #     state
    #   ])

    # end_block = 0

    Process.send(self(), :check_new_confirmations, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        new_batches_start_block: end_block + 1
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_new_confirmations, state) do
    {handle_duration, _} =
      :timer.tc(&nothing_to_do/1, [
        state
      ])

    Process.send(self(), :check_lifecycle_txs_finalization, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration)
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_lifecycle_txs_finalization, state) do
    {handle_duration, _} =
      if state.config.track_l1_tx_finalization do
        :timer.tc(&monitor_lifecycle_txs_finalization/1, [
          state
        ])
      else
        {0, nil}
      end

    Process.send_after(
      self(),
      :check_new_batches,
      max(:timer.seconds(state.config.recheck_interval) - div(increase_duration(state.data, handle_duration), 1000), 0)
    )

    new_data =
      Map.merge(state.data, %{
        duration: 0
      })

    {:noreply, %{state | data: new_data}}
  end

  defp get_logs_new_batches(start_block, end_block, sequencer_inbox_address, json_rpc_named_arguments)
       when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        sequencer_inbox_address,
        [@message_sequencer_batch_delivered],
        json_rpc_named_arguments
      )

    if length(logs) > 0 do
      Logger.info("Found #{length(logs)} SequencerBatchDelivered logs")
    end

    logs
  end

  defp sequencer_batch_delivered_event_parse(event) do
    [_, batch_sequence_number, before_acc, after_acc] = event["topics"]

    {quantity_to_integer(batch_sequence_number), before_acc, after_acc}
  end

  defp add_sequencer_l2_batch_from_origin_calldata_parse(calldata) do
    "0x8f111f3c" <> encoded_params = calldata

    # addSequencerL2BatchFromOrigin(uint256 sequenceNumber, bytes calldata data, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount)
    [sequence_number, _data, _after_delayed_messages_read, _gas_refunder, prev_message_count, new_message_count] =
      TypeDecoder.decode(
        Base.decode16!(encoded_params, case: :lower),
        %FunctionSelector{
          function: "addSequencerL2BatchFromOrigin",
          types: [
            {:uint, 256},
            :bytes,
            {:uint, 256},
            :address,
            {:uint, 256},
            {:uint, 256}
          ]
        }
      )

    {sequence_number, prev_message_count, new_message_count}
  end

  defp parse_logs_for_new_batches(logs) do
    {batches, txs_requests, blocks_requests} =
      logs
      |> Enum.reduce({%{}, [], %{}}, fn event, {batches, txs_requests, blocks_requests} ->
        {batch_num, before_acc, after_acc} = sequencer_batch_delivered_event_parse(event)

        tx_hash = event["transactionHash"]
        blk_num = quantity_to_integer(event["blockNumber"])

        updated_batches =
          Map.put(
            batches,
            batch_num,
            %{
              number: batch_num,
              before_acc: before_acc,
              after_acc: after_acc,
              tx_hash: tx_hash
            }
          )

        updated_txs_requests = [
          Rpc.transaction_by_hash_request(%{id: 0, hash: tx_hash})
          | txs_requests
        ]

        updated_blocks_requests =
          Map.put(
            blocks_requests,
            blk_num,
            BlockByNumber.request(%{id: 0, number: blk_num}, false, true)
          )

        Logger.info("New batch #{batch_num} found in #{tx_hash}")

        {updated_batches, updated_txs_requests, updated_blocks_requests}
      end)

    {batches, txs_requests, Map.values(blocks_requests)}
  end

  defp get_l1_tx_id_by_hash(l1_txs, hash) do
    l1_txs
    |> Map.get(hash)
    |> Kernel.||(%{id: nil})
    |> Map.get(:id)
  end

  defp get_batches_from_logs(logs, msg_to_block_shift, track_finalization?, json_rpc_named_arguments, chunk_size) do
    {batches, txs_requests, blocks_requests} = parse_logs_for_new_batches(logs)

    blocks_to_ts = Rpc.execute_blocks_requests_and_get_ts(blocks_requests, json_rpc_named_arguments, chunk_size)

    {lifecycle_txs_wo_indices, batches_to_import} =
      txs_requests
      |> list_to_chunks(chunk_size)
      |> Enum.reduce({%{}, batches}, fn chunk, {l1_txs, updated_batches} ->
        chunk
        # each eth_getTransactionByHash will take time since it returns entire batch
        # in `input` which is heavy because contains dozens of rollup blocks
        |> Rpc.make_chunked_request(json_rpc_named_arguments, "eth_getTransactionByHash")
        |> Enum.reduce({l1_txs, updated_batches}, fn resp, {txs_map, batches_map} ->
          block_num = quantity_to_integer(resp["blockNumber"])
          tx_hash = resp["hash"]

          # Every message is an L2 block
          {batch_num, prev_message_count, new_message_count} =
            add_sequencer_l2_batch_from_origin_calldata_parse(resp["input"])

          updated_batches_map =
            Map.put(
              batches_map,
              batch_num,
              Map.merge(batches_map[batch_num], %{
                start_block: prev_message_count + msg_to_block_shift,
                end_block: new_message_count + msg_to_block_shift - 1
              })
            )

          updated_txs_map =
            Map.put(txs_map, tx_hash, %{
              hash: tx_hash,
              block: block_num,
              timestamp: blocks_to_ts[block_num],
              status:
                if track_finalization? do
                  :unfinalized
                else
                  :finalized
                end
            })

          {updated_txs_map, updated_batches_map}
        end)
      end)

    lifecycle_txs =
      lifecycle_txs_wo_indices
      |> Db.get_indices_for_l1_transactions()

    batches_list_to_import =
      batches_to_import
      |> Map.values()
      |> Enum.reduce([], fn batch, updated_batches_list ->
        [
          # TODO
          batch
          |> Map.put(:commit_id, get_l1_tx_id_by_hash(lifecycle_txs, batch.tx_hash))
          |> Map.put(:tx_count, 0)
          |> Map.drop([:tx_hash])
          | updated_batches_list
        ]
      end)

    {batches_list_to_import, Map.values(lifecycle_txs)}
  end

  defp discover_new_batches(state) do
    # Requesting the "latest" block instead of "safe" allows to catch new batches
    # without latency.
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        "latest",
        state.config.json_l1_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    start_block = state.data.new_batches_start_block
    end_block = min(start_block + state.config.l1_rpc_block_range - 1, latest_block)

    if start_block <= end_block do
      Logger.info("Block range for new batches discovery: #{start_block}..#{end_block}")

      logs =
        get_logs_new_batches(
          start_block,
          end_block,
          state.config.l1_sequencer_inbox_address,
          state.config.json_l1_rpc_named_arguments
        )

      {batches, lifecycle_txs} =
        get_batches_from_logs(
          logs,
          state.config.messages_to_blocks_shift,
          state.config.track_l1_tx_finalization,
          state.config.json_l1_rpc_named_arguments,
          state.config.l1_rpc_chunk_size
        )

      {:ok, _} =
        Chain.import(%{
          arbitrum_lifecycle_transactions: %{params: lifecycle_txs},
          arbitrum_l1_batches: %{params: batches},
          timeout: :infinity
        })

      {:ok, end_block}
    else
      {:ok, start_block - 1}
    end
  end

  defp monitor_lifecycle_txs_finalization(state) do
    {:ok, safe_block} =
      IndexerHelper.get_block_number_by_tag(
        "safe",
        state.config.json_l1_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    lifecycle_txs = Reader.lifecycle_unfinalized_transactions(safe_block)

    if length(lifecycle_txs) > 0 do
      Logger.info("Discovered #{length(lifecycle_txs)} lifecycle transaction to be finalized")

      updated_lifecycle_txs =
        lifecycle_txs
        |> Enum.map(fn tx ->
          tx
          |> Db.transform_lifecycle_transaction_to_map()
          |> Map.put(:status, :finalized)
        end)

      {:ok, _} =
        Chain.import(%{
          arbitrum_lifecycle_transactions: %{params: updated_lifecycle_txs},
          timeout: :infinity
        })
    end
  end

  defp nothing_to_do(_) do
    :timer.sleep(500)
  end
end
