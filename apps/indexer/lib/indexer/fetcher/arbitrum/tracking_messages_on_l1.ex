defmodule Indexer.Fetcher.Arbitrum.TrackingMessagesOnL1 do
  @moduledoc """
  TBD
  """

  use GenServer
  use Indexer.Fetcher

  import Indexer.Fetcher.Arbitrum.Utils.Helper, only: [increase_duration: 2]

  alias Indexer.Fetcher.Arbitrum.Workers.NewMessagesToL2

  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}

  require Logger

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
    l1_rollup_init_block = config_common[:l1_rollup_init_block]
    l1_start_block = max(config_common[:l1_start_block], l1_rollup_init_block)
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
         l1_start_block: l1_start_block,
         l1_rollup_init_block: l1_rollup_init_block
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

    new_msg_to_l2_start_block = Db.l1_block_to_discover_latest_message_to_l2(state.config.l1_start_block)
    historical_msg_to_l2_end_block = Db.l1_block_to_discover_earliest_message_to_l2(state.config.l1_start_block - 1)

    Process.send(self(), :check_new_msgs_to_rollup, [])

    new_state =
      state
      |> Map.put(:config, Map.put(state.config, :l1_bridge_address, bridge_address))
      |> Map.put(
        :data,
        Map.merge(state.data, %{
          new_msg_to_l2_start_block: new_msg_to_l2_start_block,
          historical_msg_to_l2_end_block: historical_msg_to_l2_end_block
        })
      )

    {:noreply, new_state}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_new_msgs_to_rollup, state) do
    {handle_duration, {:ok, end_block}} =
      :timer.tc(&discover_new_messages_to_l2/1, [
        state
      ])

    Process.send(self(), :check_historical_msgs_to_rollup, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        new_msg_to_l2_start_block: end_block + 1
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_historical_msgs_to_rollup, state) do
    {handle_duration, {:ok, start_block}} =
      :timer.tc(&discover_historical_messages_to_l2/1, [
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
        historical_msg_to_l2_end_block: start_block - 1
      })

    {:noreply, %{state | data: new_data}}
  end

  defp discover_new_messages_to_l2(
         %{
           config: %{
             json_l1_rpc_named_arguments: json_rpc_named_arguments,
             l1_rpc_chunk_size: chunk_size,
             l1_rpc_block_range: rpc_block_range,
             l1_bridge_address: bridge_address
           },
           data: %{new_msg_to_l2_start_block: start_block}
         } = _state
       ) do
    # Requesting the "latest" block instead of "safe" allows to get messages originated to L2
    # much earlier than they will be seen by the Arbitrum Sequencer.
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        "latest",
        json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    end_block = min(start_block + rpc_block_range - 1, latest_block)

    if start_block <= end_block do
      Logger.info("Block range for discovery new messages from L1: #{start_block}..#{end_block}")

      NewMessagesToL2.discover(
        bridge_address,
        start_block,
        end_block,
        json_rpc_named_arguments,
        chunk_size
      )

      {:ok, end_block}
    else
      {:ok, start_block - 1}
    end
  end

  defp discover_historical_messages_to_l2(
         %{
           config: %{
             json_l1_rpc_named_arguments: json_rpc_named_arguments,
             l1_rpc_chunk_size: chunk_size,
             l1_rpc_block_range: rpc_block_range,
             l1_bridge_address: bridge_address,
             l1_rollup_init_block: l1_rollup_init_block
           },
           data: %{historical_msg_to_l2_end_block: end_block}
         } = _state
       ) do
    if end_block >= l1_rollup_init_block do
      start_block = max(l1_rollup_init_block, end_block - rpc_block_range + 1)

      Logger.info("Block range for discovery historical messages from L1: #{start_block}..#{end_block}")

      NewMessagesToL2.discover(
        bridge_address,
        start_block,
        end_block,
        json_rpc_named_arguments,
        chunk_size
      )

      {:ok, start_block}
    else
      {:ok, l1_rollup_init_block}
    end
  end
end
