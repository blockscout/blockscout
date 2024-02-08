defmodule Indexer.Fetcher.Arbitrum.TrackingMessagesOnL1 do
  @moduledoc """
  TBD
  """

  use GenServer
  use Indexer.Fetcher

  import EthereumJSONRPC,
    only: [json_rpc: 2, quantity_to_integer: 1]

  import Explorer.Helper, only: [decode_data: 2]

  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum.Reader

  require Logger

  @rpc_resend_attempts 20

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

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    l1_rpc = config_tracker[:l1_rpc]
    l1_rpc_block_range = config_tracker[:l1_rpc_block_range]
    l1_bridge_address = config_tracker[:l1_bridge_address]
    l1_bridge_start_block = config_tracker[:l1_bridge_start_block]
    recheck_interval = config_tracker[:recheck_interval]
    chunk_size = config_tracker[:chunk_size]

    Process.send(self(), :init_start_position, [])

    {:ok,
     %{
       config: %{
         json_l2_rpc_named_arguments: args[:json_rpc_named_arguments],
         json_l1_rpc_named_arguments: [
           transport: EthereumJSONRPC.HTTP,
           transport_options: [
             http: EthereumJSONRPC.HTTP.HTTPoison,
             url: l1_rpc,
             http_options: [
               recv_timeout: :timer.minutes(10),
               timeout: :timer.minutes(10),
               hackney: [pool: :ethereum_jsonrpc]
             ]
           ]
         ],
         recheck_interval: recheck_interval,
         chunk_size: chunk_size,
         l1_rpc_block_range: l1_rpc_block_range,
         l1_bridge_address: l1_bridge_address,
         l1_bridge_start_block: l1_bridge_start_block
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
  def handle_info(:init_start_position, state) do
    new_msg_to_l2_start_block =
      case Reader.latest_completed_message_to_l2() do
        nil ->
          Logger.warning("No completed messages to L2 found in DB")
          state.config.l1_bridge_start_block

        value ->
          value + 1
      end

    Process.send(self(), :check_new_msgs_to_rollup, [])

    {:noreply, %{state | data: %{new_msg_to_l2_start_block: new_msg_to_l2_start_block}}}
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
      max(:timer.seconds(state.config.recheck_interval) - div(update_duration(state.data, handle_duration), 1000), 0)
    )

    new_data =
      Map.merge(state.data, %{
        duration: update_duration(state.data, handle_duration),
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

  defp parse_get_logs_for_l1_to_l2_messages(logs) do
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
              EthereumJSONRPC.request(%{
                id: 0,
                method: "eth_getTransactionByHash",
                params: [tx_hash]
              })
            )

          Logger.info("L1 to L2 message #{tx_hash} found with the type #{type}")

          {updated_messages, updated_txs_requests}
        else
          {messages, txs_requests}
        end
      end)

    {messages, Map.values(txs_requests)}
  end

  defp list_to_chunks(l, chunk_size) do
    {chunks, cur_chunk, cur_chunk_size} =
      l
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce({[], [], 0}, fn chunk, {chunks, cur_chunk, cur_chunk_size} ->
        new_cur_chunk = [chunk | cur_chunk]

        if cur_chunk_size + 1 == chunk_size do
          {[new_cur_chunk | chunks], [], 0}
        else
          {chunks, new_cur_chunk, cur_chunk_size + 1}
        end
      end)

    if cur_chunk_size != 0 do
      [cur_chunk | chunks]
    else
      chunks
    end
  end

  defp make_chunked_request(requests_list, json_rpc_named_arguments, help_str) do
    error_message = &"Cannot call #{help_str}. Error: #{inspect(&1)}"

    {:ok, responses} =
      IndexerHelper.repeated_call(
        &json_rpc/2,
        [requests_list, json_rpc_named_arguments],
        error_message,
        @rpc_resend_attempts
      )

    Enum.map(responses, fn %{result: block_desc} -> block_desc end)
  end

  # defp execute_blocks_requests_and_get_timestamps(blocks_requests, json_rpc_named_arguments, chunk_size) do
  #   list_to_chunks(blocks_requests, chunk_size)
  #   |> Enum.reduce(%{}, fn chunk, blocks_to_ts ->
  #     make_chunked_request(chunk, json_rpc_named_arguments, "eth_getBlockByNumber")
  #     |> Enum.reduce(blocks_to_ts, fn resp, blocks_to_ts_inner ->
  #       Map.put(blocks_to_ts_inner, quantity_to_integer(resp["number"]), timestamp_to_datetime(resp["timestamp"]))
  #     end)
  #   end)
  # end

  defp execute_transactions_requests_and_get_from(txs_requests, json_rpc_named_arguments, chunk_size) do
    list_to_chunks(txs_requests, chunk_size)
    |> Enum.reduce(%{}, fn chunk, tx_to_from ->
      make_chunked_request(chunk, json_rpc_named_arguments, "eth_getTransactionByHash")
      |> Enum.reduce(tx_to_from, fn resp, tx_to_from_inner ->
        Map.put(tx_to_from_inner, resp["hash"], resp["from"])
      end)
    end)
  end

  defp get_messages_from_logs(logs, json_rpc_named_arguments, chunk_size) do
    {messages, txs_requests} = parse_get_logs_for_l1_to_l2_messages(logs)

    txs_to_from = execute_transactions_requests_and_get_from(txs_requests, json_rpc_named_arguments, chunk_size)

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
      IndexerHelper.get_block_number_by_tag("latest", state.config.json_l1_rpc_named_arguments, @rpc_resend_attempts)

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

      messages = get_messages_from_logs(logs, state.config.json_l1_rpc_named_arguments, state.config.chunk_size)

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

  defp update_duration(data, cur_duration) do
    if Map.has_key?(data, :duration) do
      data.duration + cur_duration
    else
      cur_duration
    end
  end
end
