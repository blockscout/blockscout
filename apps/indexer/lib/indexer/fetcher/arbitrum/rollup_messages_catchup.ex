defmodule Indexer.Fetcher.Arbitrum.RollupMessagesCatchup do
  @moduledoc """
  TBD
  """

  use GenServer
  use Indexer.Fetcher

  import Indexer.Fetcher.Arbitrum.Utils.Helper, only: [increase_duration: 2]

  alias Indexer.Fetcher.Arbitrum.Utils.Db
  alias Indexer.Fetcher.Arbitrum.Workers.HistoricalMessagesOnL2

  require Logger

  @wait_for_new_block_delay 15
  @release_cpu_delay 1

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
    Logger.metadata(fetcher: :arbitrum_bridge_l2_catchup)

    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    rollup_chunk_size = config_common[:rollup_chunk_size]

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]
    messages_to_l2_blocks_depth = config_tracker[:messages_to_l2_blocks_depth]
    messages_from_l2_blocks_depth = config_tracker[:messages_to_l1_blocks_depth]

    Process.send(self(), :wait_for_new_block, [])

    {:ok,
     %{
       config: %{
         rollup_rpc: %{
           json_rpc_named_arguments: args[:json_rpc_named_arguments],
           chunk_size: rollup_chunk_size
         },
         json_l2_rpc_named_arguments: args[:json_rpc_named_arguments],
         recheck_interval: recheck_interval,
         messages_to_l2_blocks_depth: messages_to_l2_blocks_depth,
         messages_from_l2_blocks_depth: messages_from_l2_blocks_depth
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
  def handle_info(:wait_for_new_block, state) do
    {time_of_start, interim_data} =
      if is_nil(Map.get(state.data, :time_of_start)) do
        now = DateTime.utc_now()
        updated_data = Map.put(state.data, :time_of_start, now)
        {now, updated_data}
      else
        {state.data.time_of_start, state.data}
      end

    new_data =
      case Db.closest_block_after_timestamp(time_of_start) do
        {:ok, block} ->
          Process.send(self(), :init_worker, [])

          interim_data
          |> Map.put(:new_block, block)
          |> Map.delete(:time_of_start)

        {:error, _} ->
          Logger.warning("No progress of the block fetcher found")
          Process.send_after(self(), :wait_for_new_block, :timer.seconds(@wait_for_new_block_delay))
          interim_data
      end

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:init_worker, state) do
    historical_msg_from_l2_end_block = Db.rollup_block_to_discover_missed_messages_from_l2(state.data.new_block - 1)
    historical_msg_to_l2_end_block = Db.rollup_block_to_discover_missed_messages_to_l2(state.data.new_block - 1)

    Process.send(self(), :historical_msg_from_l2, [])

    new_data =
      Map.merge(state.data, %{
        duration: 0,
        historical_msg_from_l2_end_block: historical_msg_from_l2_end_block,
        historical_msg_to_l2_end_block: historical_msg_to_l2_end_block
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:historical_msg_from_l2, state) do
    end_block = state.data.historical_msg_from_l2_end_block

    {handle_duration, {:ok, start_block}} =
      :timer.tc(&HistoricalMessagesOnL2.discover_historical_messages_from_l2/2, [end_block, state])

    Process.send(self(), :historical_msg_to_l2, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        historical_msg_from_l2_end_block: if(is_nil(start_block), do: nil, else: start_block - 1)
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:historical_msg_to_l2, state) do
    end_block = state.data.historical_msg_to_l2_end_block

    {handle_duration, {:ok, start_block}} =
      :timer.tc(&HistoricalMessagesOnL2.discover_historical_messages_to_l2/2, [end_block, state])

    Process.send(self(), :plan_next_iteration, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        historical_msg_to_l2_end_block: if(is_nil(start_block), do: nil, else: start_block - 1)
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:plan_next_iteration, state) do
    next_timeout =
      if state.data.historical_msg_from_l2_end_block <= 0 and state.data.historical_msg_to_l2_end_block <= 0 do
        max(:timer.seconds(state.config.recheck_interval) - div(state.data.duration, 1000), 0)
      else
        # For the case when historical messages are not received yet
        # make a small delay to release CPU a bit
        :timer.seconds(@release_cpu_delay)
      end

    Process.send_after(self(), :historical_msg_from_l2, next_timeout)

    {:noreply, state}
  end
end
