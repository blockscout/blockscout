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

    modules_can_use_reorg_monitor = [
      Indexer.Fetcher.Shibarium.L1,
      Indexer.Fetcher.Zkevm.BridgeL1
    ]

    modules_using_reorg_monitor =
      modules_can_use_reorg_monitor
      |> Enum.reject(fn module ->
        is_nil(Application.get_all_env(:indexer)[module][:start_block])
      end)

    cond do
      Enum.count(modules_using_reorg_monitor) > 1 ->
        Logger.error("#{__MODULE__} cannot work for more than one rollup module. Please, check config.")
        :ignore

      Enum.empty?(modules_using_reorg_monitor) ->
        # don't start reorg monitor as there is no module which would use it
        :ignore

      true ->
        module_using_reorg_monitor = Enum.at(modules_using_reorg_monitor, 0)

        l1_rpc = Application.get_all_env(:indexer)[module_using_reorg_monitor][:rpc]

        json_rpc_named_arguments = Helper.json_rpc_named_arguments(l1_rpc)

        {:ok, block_check_interval, _} = Helper.get_block_check_interval(json_rpc_named_arguments)

        Process.send(self(), :reorg_monitor, [])

        {:ok,
         %{
           block_check_interval: block_check_interval,
           json_rpc_named_arguments: json_rpc_named_arguments,
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
          prev_latest: prev_latest
        } = state
      ) do
    {:ok, latest} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

    if latest < prev_latest do
      Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")
      reorg_block_push(latest)
    end

    Process.send_after(self(), :reorg_monitor, block_check_interval)

    {:noreply, %{state | prev_latest: latest}}
  end

  @doc """
  Pops the number of reorg block from the front of the queue.
  Returns `nil` if the reorg queue is empty.
  """
  @spec reorg_block_pop() :: non_neg_integer() | nil
  def reorg_block_pop do
    table_name = reorg_table_name(@fetcher_name)

    case BoundQueue.pop_front(reorg_queue_get(table_name)) do
      {:ok, {block_number, updated_queue}} ->
        :ets.insert(table_name, {:queue, updated_queue})
        block_number

      {:error, :empty} ->
        nil
    end
  end

  defp reorg_block_push(block_number) do
    table_name = reorg_table_name(@fetcher_name)
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

  defp reorg_table_name(fetcher_name) do
    :"#{fetcher_name}#{:_reorgs}"
  end
end
