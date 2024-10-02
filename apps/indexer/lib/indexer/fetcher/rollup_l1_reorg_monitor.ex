defmodule Indexer.Fetcher.RollupL1ReorgMonitor do
  @moduledoc """
  A module to catch L1 reorgs and make queue of the reorg blocks (if there are multiple reorgs).

  A rollup module uses the queue to detect a reorg and to do required actions.
  In case of reorg, the block number is popped from the queue for that rollup module.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Indexer.{BoundQueue, Helper}
  alias Indexer.Fetcher.{Optimism, PolygonEdge}

  @fetcher_name :rollup_l1_reorg_monitor

  case Application.compile_env(:explorer, :chain_type) do
    :optimism ->
      @modules_can_use_reorg_monitor [
        Indexer.Fetcher.Optimism.OutputRoot,
        Indexer.Fetcher.Optimism.TransactionBatch,
        Indexer.Fetcher.Optimism.WithdrawalEvent
      ]

    :polygon_edge ->
      @modules_can_use_reorg_monitor [
        Indexer.Fetcher.PolygonEdge.Deposit,
        Indexer.Fetcher.PolygonEdge.WithdrawalExit
      ]

    :polygon_zkevm ->
      @modules_can_use_reorg_monitor [
        Indexer.Fetcher.PolygonZkevm.BridgeL1
      ]

    :scroll ->
      @modules_can_use_reorg_monitor [
        Indexer.Fetcher.Scroll.BridgeL1
      ]

    :shibarium ->
      @modules_can_use_reorg_monitor [
        Indexer.Fetcher.Shibarium.L1
      ]

    _ ->
      @modules_can_use_reorg_monitor []
  end

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

    modules_using_reorg_monitor =
      @modules_can_use_reorg_monitor
      |> Enum.filter(fn module ->
        if Application.get_env(:explorer, :chain_type) == :optimism do
          Optimism.requires_l1_reorg_monitor?()
        else
          module.requires_l1_reorg_monitor?()
        end
      end)

    if Enum.empty?(modules_using_reorg_monitor) do
      # don't start reorg monitor as there is no module which would use it
      :ignore
    else
      chain_type = Application.get_env(:explorer, :chain_type)

      l1_rpc =
        cond do
          chain_type == :optimism ->
            Optimism.l1_rpc_url()

          chain_type == :polygon_edge ->
            PolygonEdge.l1_rpc_url()

          true ->
            module = Enum.at(modules_using_reorg_monitor, 0)
            module.l1_rpc_url()
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
    {:ok, latest} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number())

    if latest < prev_latest do
      Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")
      Enum.each(modules, &reorg_block_push(latest, &1))
    end

    Process.send_after(self(), :reorg_monitor, block_check_interval)

    {:noreply, %{state | prev_latest: latest}}
  end

  @doc """
  Pops the number of reorg block from the front of the queue for the specified rollup module.

  ## Parameters
  - `module`: The module for which the block number is popped from the queue.

  ## Returns
  - The popped block number.
  - `nil` if the reorg queue is empty.
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

  @doc """
  Pushes the number of reorg block to the back of the queue for the specified rollup module.

  ## Parameters
  - `block_number`: The reorg block number.
  - `module`: The module for which the block number is pushed to the queue.

  ## Returns
  - Nothing is returned.
  """
  @spec reorg_block_push(non_neg_integer(), module()) :: any()
  def reorg_block_push(block_number, module) do
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
