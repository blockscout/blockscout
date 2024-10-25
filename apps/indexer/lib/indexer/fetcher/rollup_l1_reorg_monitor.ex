defmodule Indexer.Fetcher.RollupL1ReorgMonitor do
  @moduledoc """
  A module to monitor and catch L1 reorgs and make queue of the reorg blocks
  (if there are multiple reorgs) for rollup modules using this monitor.

  A rollup module uses the queue to detect a reorg and to do required actions.
  In case of reorg, the block number is popped from the queue by that rollup module.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Indexer.Helper

  @fetcher_name :rollup_l1_reorg_monitor

  @modules_can_use_reorg_monitor (case Application.compile_env(:explorer, :chain_type) do
                                    :optimism ->
                                      [
                                        Indexer.Fetcher.Optimism.OutputRoot,
                                        Indexer.Fetcher.Optimism.TransactionBatch,
                                        Indexer.Fetcher.Optimism.WithdrawalEvent
                                      ]

                                    :polygon_edge ->
                                      [
                                        Indexer.Fetcher.PolygonEdge.Deposit,
                                        Indexer.Fetcher.PolygonEdge.WithdrawalExit
                                      ]

                                    :polygon_zkevm ->
                                      [
                                        Indexer.Fetcher.PolygonZkevm.BridgeL1
                                      ]

                                    :scroll ->
                                      [
                                        Indexer.Fetcher.Scroll.Batch,
                                        Indexer.Fetcher.Scroll.BridgeL1
                                      ]

                                    :shibarium ->
                                      [
                                        Indexer.Fetcher.Shibarium.L1
                                      ]

                                    _ ->
                                      []
                                  end)

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

  @doc """
    This function initializes L1 blocks reorg monitor for the current rollup
    defined by CHAIN_TYPE. If the current chain is not a rollup, the module just doesn't start.

    The monitor is launched for certain modules of the rollup defined in @modules_can_use_reorg_monitor attribute
    if a module starts (it can be switched off by configuration parameters). Whether each module starts or not
    is defined by the `requires_l1_reorg_monitor?` function of that module.

    The monitor starts an infinite loop of `eth_getBlockByNumber` requests sending them every
    `block_check_interval` milliseconds to retrieve the latest block number. To read the latest
    block number, RPC node of Layer 1 is used, which URL is defined by `l1_rpc_url` function of the rollup module.
    The `block_check_interval` is determined by the `get_block_check_interval` helper function.
    After the `block_check_interval` is defined, the function sends `:reorg_monitor` message to the GenServer
    to start the monitor loop.

    ## Returns
    - `{:ok, state}` with the determined parameters for the monitor loop if at least one rollup module is launched.
    - `:ignore` if the monitor is not needed.
  """
  @impl GenServer
  def init(_args) do
    Logger.metadata(fetcher: @fetcher_name)

    modules_using_reorg_monitor =
      @modules_can_use_reorg_monitor
      |> Enum.filter(& &1.requires_l1_reorg_monitor?())

    if Enum.empty?(modules_using_reorg_monitor) do
      # don't start reorg monitor as there is no module which would use it
      :ignore
    else
      l1_rpc = Enum.at(modules_using_reorg_monitor, 0).l1_rpc_url()

      json_rpc_named_arguments = Helper.json_rpc_named_arguments(l1_rpc)

      {:ok, block_check_interval, _} = Helper.get_block_check_interval(json_rpc_named_arguments)

      Process.send(self(), :reorg_monitor, [])

      {:ok,
       %{
         block_check_interval: block_check_interval,
         json_rpc_named_arguments: json_rpc_named_arguments,
         modules: modules_using_reorg_monitor,
         prev_latest: 0
       }}
    end
  end

  @doc """
    Implements the monitor loop which requests RPC node for the latest block every
    `block_check_interval` milliseconds using `eth_getBlockByNumber` request.

    In case of reorg, the reorg block number is pushed into rollup module's queue.
    The block numbers are then popped by the rollup module from its queue and
    used to do some actions needed after reorg.

    ## Parameters
    - `:reorg_monitor`: The message triggering the next monitoring iteration.
    - `state`: The current state of the process, containing parameters for the
               monitoring (such as `block_check_interval`, `json_rpc_named_arguments`,
               the list of rollup modules in need of monitoring, the previous latest
               block number).

    ## Returns
    - `{:noreply, state}` where `state` contains the updated previous latest block number.
  """
  @impl GenServer
  def handle_info(
        :reorg_monitor,
        %{
          block_check_interval: block_check_interval,
          json_rpc_named_arguments: json_rpc_named_arguments,
          modules: modules,
          prev_latest: prev_latest
        } = state
      ) do
    {:ok, latest} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number())

    if latest < prev_latest do
      Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")
      Enum.each(modules, &RollupReorgMonitorQueue.reorg_block_push(latest, &1))
    end

    Process.send_after(self(), :reorg_monitor, block_check_interval)

    {:noreply, %{state | prev_latest: latest}}
  end
end
