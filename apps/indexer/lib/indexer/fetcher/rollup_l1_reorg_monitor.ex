defmodule Indexer.Fetcher.RollupL1ReorgMonitor do
  @moduledoc """
  A module to catch L1 reorgs and notify a rollup module about it.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Indexer.{BoundQueue, Helper}

  @fetcher_name :rollup_l1_reorg_monitor

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
    Logger.metadata(fetcher: @fetcher_name)

    optimism_modules = [
      Indexer.Fetcher.Optimism.OutputRoot,
      Indexer.Fetcher.Optimism.TxnBatch,
      Indexer.Fetcher.Optimism.WithdrawalEvent
    ]

    modules_can_use_reorg_monitor =
      optimism_modules ++
        [
          Indexer.Fetcher.PolygonEdge.Deposit,
          Indexer.Fetcher.PolygonEdge.WithdrawalExit,
          Indexer.Fetcher.PolygonZkevm.BridgeL1,
          Indexer.Fetcher.Shibarium.L1
        ]

    modules_using_reorg_monitor =
      modules_can_use_reorg_monitor
      |> Enum.reject(fn module ->
        if module in optimism_modules do
          optimism_config = Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism]
          is_nil(optimism_config[:optimism_l1_system_config])
        else
          module_config = Application.get_all_env(:indexer)[module]
          is_nil(module_config[:start_block]) and is_nil(module_config[:start_block_l1])
        end
      end)

    if Enum.empty?(modules_using_reorg_monitor) do
      # don't start reorg monitor as there is no module which would use it
      :ignore
    else
      # As there cannot be different modules for different rollups at the same time,
      # it's correct to only get the first item of the list.
      # For example, Indexer.Fetcher.PolygonEdge.Deposit and Indexer.Fetcher.PolygonEdge.WithdrawalExit can be in the list
      # because they are for the same rollup, but Indexer.Fetcher.Shibarium.L1 and Indexer.Fetcher.PolygonZkevm.BridgeL1 cannot (as they are for different rollups).
      module_using_reorg_monitor = Enum.at(modules_using_reorg_monitor, 0)

      l1_rpc =
        cond do
          Enum.member?(
            [Indexer.Fetcher.PolygonEdge.Deposit, Indexer.Fetcher.PolygonEdge.WithdrawalExit],
            module_using_reorg_monitor
          ) ->
            # there can be more than one PolygonEdge.* modules, so we get the common L1 RPC URL for them from Indexer.Fetcher.PolygonEdge
            Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonEdge][:polygon_edge_l1_rpc]

          Enum.member?(
            optimism_modules,
            module_using_reorg_monitor
          ) ->
            # there can be more than one Optimism.* modules, so we get the common L1 RPC URL for them from Indexer.Fetcher.Optimism
            Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism][:optimism_l1_rpc]

          true ->
            Application.get_all_env(:indexer)[module_using_reorg_monitor][:rpc]
        end

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
    {:ok, latest} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

    if latest < prev_latest do
      Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")
      Enum.each(modules, &reorg_block_push(latest, &1))
    end

    Process.send_after(self(), :reorg_monitor, block_check_interval)

    {:noreply, %{state | prev_latest: latest}}
  end

  @doc """
  Pops the number of reorg block from the front of the queue for the specified rollup module.
  Returns `nil` if the reorg queue is empty.
  """
  @spec reorg_block_pop(module()) :: non_neg_integer() | nil
  def reorg_block_pop(module) do
    table_name = reorg_table_name(module)

    case BoundQueue.pop_front(reorg_queue_get(table_name)) do
      {:ok, {block_number, updated_queue}} ->
        :ets.insert(table_name, {:queue, updated_queue})
        block_number

      {:error, :empty} ->
        nil
    end
  end

  defp reorg_block_push(block_number, module) do
    table_name = reorg_table_name(module)
    {:ok, updated_queue} = BoundQueue.push_back(reorg_queue_get(table_name), block_number)
    :ets.insert(table_name, {:queue, updated_queue})
  end

  defp reorg_queue_get(table_name) do
    if :ets.whereis(table_name) == :undefined do
      :ets.new(table_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    with info when info != :undefined <- :ets.info(table_name),
         [{_, value}] <- :ets.lookup(table_name, :queue) do
      value
    else
      _ -> %BoundQueue{}
    end
  end

  defp reorg_table_name(module) do
    :"#{module}#{:_reorgs}"
  end
end
