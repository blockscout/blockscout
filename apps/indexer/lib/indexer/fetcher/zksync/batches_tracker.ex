defmodule Indexer.Fetcher.ZkSync.BatchesStatusTracker do
  @moduledoc """
    Updates batches statuses and receives historical batches
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  # alias Explorer.Chain.Events.Publisher
  # TODO: publish event when new commited batches appear

  alias Indexer.Fetcher.ZkSync.Discovery.Workers
  alias Indexer.Fetcher.ZkSync.StatusTracking.Committed
  alias Indexer.Fetcher.ZkSync.StatusTracking.Proven
  alias Indexer.Fetcher.ZkSync.StatusTracking.Executed

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
    Logger.metadata(fetcher: :zksync_batches_tracker)

    config_tracker = Application.get_all_env(:indexer)[Indexer.Fetcher.ZkSync.BatchesStatusTracker]
    l1_rpc = config_tracker[:zksync_l1_rpc]
    recheck_interval = config_tracker[:recheck_interval]
    config_fetcher = Application.get_all_env(:indexer)[Indexer.Fetcher.ZkSync.TransactionBatch]
    chunk_size = config_fetcher[:chunk_size]
    batches_max_range = config_fetcher[:batches_max_range]

    Process.send(self(), :check_committed, [])

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
         batches_max_range: batches_max_range
       },
       data: %{}
     }}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:check_historical, state) do
    {handle_duration, _} = :timer.tc(&Workers.batches_catchup/1, [state.config])

    Process.send_after(
      self(),
      :check_committed,
      max(:timer.seconds(state.config.recheck_interval) - div(update_duration(state.data, handle_duration), 1000), 0)
    )

    {:noreply, %{state | data: %{}}}
  end

  @impl GenServer
  def handle_info(:recover_batches, state) do
    {handle_duration, _} =
      :timer.tc(
        &Workers.get_full_batches_info_and_import/2,
        [state.data.batches, state.config]
      )

    Process.send(self(), state.data.switched_from, [])

    {:noreply, %{state | data: %{duration: update_duration(state.data, handle_duration)}}}
  end

  @impl GenServer
  def handle_info(input, state)
      when input in [:check_committed, :check_proven, :check_executed] do
    {output, func} =
      case input do
        :check_committed -> {:check_proven, &Committed.look_for_batches_and_update/1}
        :check_proven -> {:check_executed, &Proven.look_for_batches_and_update/1}
        :check_executed -> {:check_historical, &Executed.look_for_batches_and_update/1}
      end

    {handle_duration, result} = :timer.tc(func, [state.config])

    {switch_to, state_data} =
      case result do
        :ok ->
          {output, %{duration: update_duration(state.data, handle_duration)}}

        {:recovery_required, batches} ->
          {:recover_batches,
           %{
             switched_from: input,
             batches: batches,
             duration: update_duration(state.data, handle_duration)
           }}
      end

    Process.send(self(), switch_to, [])
    {:noreply, %{state | data: state_data}}
  end

  defp update_duration(data, cur_duration) do
    if Map.has_key?(data, :duration) do
      data.duration + cur_duration
    else
      cur_duration
    end
  end
end
