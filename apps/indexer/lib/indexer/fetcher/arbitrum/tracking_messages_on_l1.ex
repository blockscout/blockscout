defmodule Indexer.Fetcher.Arbitrum.TrackingMessagesOnL1 do
  @moduledoc """
  TBD
  """

  use GenServer
  use Indexer.Fetcher

  import EthereumJSONRPC,
    only: [quantity_to_integer: 1]

  import Explorer.Helper, only: [decode_data: 2]

  import Indexer.Fetcher.Arbitrum.Utils.Helper, only: [increase_duration: 2]

  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}

  alias Explorer.Chain

  require Logger

  @types_of_l1_messages_forwarded_to_l2 [3, 7, 9, 12]

  # keccak256("MessageDelivered(uint256,bytes32,address,uint8,address,bytes32,uint256,uint64)")
  @message_delivered_event "0x5e3c1311ea442664e8b1611bfabef659120ea7a0a2cfc0667700bebc69cbffe1"
  @message_delivered_event_unindexed_params [
    :address,
    {:uint, 8},
    :address,
    {:bytes, 32},
    {:uint, 256},
    {:uint, 64}
  ]

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
    Logger.metadata(fetcher: :arbitrum_bridge_l1_tracker)

    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    l1_rpc = config_common[:l1_rpc]
    l1_rpc_block_range = config_common[:l1_rpc_block_range]
    l1_rollup_address = config_common[:l1_rollup_address]
    l1_start_block = config_common[:l1_start_block]
    l1_rpc_chunk_size = config_common[:l1_rpc_chunk_size]

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]

    Process.send(self(), :init_worker, [])

    {:ok,
     %{
       config: %{
         json_l2_rpc_named_arguments: args[:json_rpc_named_arguments],
         json_l1_rpc_named_arguments: IndexerHelper.build_json_rpc_named_arguments(l1_rpc),
         recheck_interval: recheck_interval,
         l1_rpc_chunk_size: l1_rpc_chunk_size,
         l1_rpc_block_range: l1_rpc_block_range,
         l1_rollup_address: l1_rollup_address,
         l1_start_block: l1_start_block
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
    %{bridge: bridge_address} =
      Rpc.get_contracts_for_rollup(state.config.l1_rollup_address, :bridge, state.config.json_l1_rpc_named_arguments)

    new_msg_to_l2_start_block = Db.l1_block_of_latest_discovered_message_to_l2(state.config.l1_start_block)

    Process.send(self(), :check_new_msgs_to_rollup, [])

    new_state =
      state
      |> Map.put(:config, Map.put(state.config, :l1_bridge_address, bridge_address))
      |> Map.put(:data, Map.put(state.data, :new_msg_to_l2_start_block, new_msg_to_l2_start_block))

    {:noreply, new_state}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_new_msgs_to_rollup, state) do
    {handle_duration, {:ok, end_block}} =
      :timer.tc(&discover_new_messages_to_l1/1, [
        state
      ])

    Process.send_after(
      self(),
      :check_new_msgs_to_rollup,
      max(:timer.seconds(state.config.recheck_interval) - div(increase_duration(state.data, handle_duration), 1000), 0)
    )

    new_data =
      Map.merge(state.data, %{
        duration: 0,
        new_msg_to_l2_start_block: end_block + 1
      })

    {:noreply, %{state | data: new_data}}
  end

  defp get_logs_for_l1_to_l2_messages(start_block, end_block, bridge_address, json_rpc_named_arguments)
       when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        bridge_address,
        [@message_delivered_event],
        json_rpc_named_arguments
      )

    if length(logs) > 0 do
      Logger.info("Found #{length(logs)} MessageDelivered logs")
    end

    logs
  end

  defp message_delivered_event_parse(event) do
    [
      _inbox,
      kind,
      _sender,
      _message_data_hash,
      _base_fee_l1,
      timestamp
    ] = decode_data(event["data"], @message_delivered_event_unindexed_params)

    message_index = quantity_to_integer(Enum.at(event["topics"], 1))

    {message_index, kind, Timex.from_unix(timestamp)}
  end

  defp parse_logs_for_l1_to_l2_messages(logs) do
    {messages, txs_requests} =
      logs
      |> Enum.reduce({[], %{}}, fn event, {messages, txs_requests} ->
        {msg_id, type, ts} = message_delivered_event_parse(event)

        if type in @types_of_l1_messages_forwarded_to_l2 do
          tx_hash = event["transactionHash"]
          blk_num = quantity_to_integer(event["blockNumber"])

          updated_messages = [
            %{
              direction: :to_l2,
              message_id: msg_id,
              originating_tx_hash: tx_hash,
              origination_timestamp: ts,
              originating_tx_blocknum: blk_num
            }
            | messages
          ]

          updated_txs_requests =
            Map.put(
              txs_requests,
              tx_hash,
              Rpc.transaction_by_hash_request(%{id: 0, hash: tx_hash})
            )

          Logger.info("L1 to L2 message #{tx_hash} found with the type #{type}")

          {updated_messages, updated_txs_requests}
        else
          {messages, txs_requests}
        end
      end)

    {messages, Map.values(txs_requests)}
  end

  defp get_messages_from_logs(logs, json_rpc_named_arguments, chunk_size) do
    {messages, txs_requests} = parse_logs_for_l1_to_l2_messages(logs)

    txs_to_from = Rpc.execute_transactions_requests_and_get_from(txs_requests, json_rpc_named_arguments, chunk_size)

    Enum.map(messages, fn msg ->
      Map.merge(msg, %{
        originator_address: txs_to_from[msg.originating_tx_hash],
        status: :initiated
      })
    end)
  end

  defp discover_new_messages_to_l1(state) do
    # Requesting the "latest" block instead of "safe" allows to get messages originated to L2
    # much earlier than they will be seen by the Arbitrum Sequencer.
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        "latest",
        state.config.json_l1_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    start_block = state.data.new_msg_to_l2_start_block
    end_block = min(start_block + state.config.l1_rpc_block_range - 1, latest_block)

    if start_block <= end_block do
      Logger.info("Block range: #{start_block}..#{end_block}")

      logs =
        get_logs_for_l1_to_l2_messages(
          start_block,
          end_block,
          state.config.l1_bridge_address,
          state.config.json_l1_rpc_named_arguments
        )

      messages = get_messages_from_logs(logs, state.config.json_l1_rpc_named_arguments, state.config.l1_rpc_chunk_size)

      {:ok, _} =
        Chain.import(%{
          arbitrum_messages: %{params: messages},
          timeout: :infinity
        })

      {:ok, end_block}
    else
      {:ok, start_block - 1}
    end
  end
end
