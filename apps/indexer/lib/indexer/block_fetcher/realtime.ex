defmodule Indexer.BlockFetcher.Realtime do
  @moduledoc """
  Fetches and indexes block ranges from latest block forward.
  """

  require Logger

  import Indexer.BlockFetcher, only: [stream_import: 1]

  alias Indexer.{BlockFetcher, Sequence}

  @enforce_keys ~w(block_fetcher interval)a
  defstruct block_fetcher: nil,
            interval: nil,
            task_by_ref: %{}

  def new(%{block_fetcher: %BlockFetcher{} = common_block_fetcher, block_interval: block_interval}) do
    block_fetcher = %BlockFetcher{
      block_fetcher | blocks_concurrency: 1, broadcast: true}

    interval = div(block_interval, 2)

    %__MODULE__{block_fetcher: block_fetcher, interval: interval}
  end

  @doc """
  Starts `task/1` and puts it in `t:Indexer.BlockFetcher.t/0` `realtime_task_by_ref`.
  """
  def put(%BlockFetcher.Supervisor{realtime: %__MODULE__{} = state} = supervisor_state) do
    %Task{ref: ref} = task = Task.Supervisor.async_nolink(Indexer.TaskSupervisor, __MODULE__, :task, [state])

    put_in(supervisor_state.realtime.task_by_ref[ref], task)
  end

  def task(%__MODULE__{block_fetcher: %BlockFetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher}) do
    {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)
    {:ok, sequence} = Sequence.start_link(first: latest_block_number, step: 2)
    stream_import(%BlockFetcher{block_fetcher | sequence: sequence})
  end

  def handle_success(
        {ref, :ok = result},
        %BlockFetcher.Supervisor{realtime: %__MODULE__{task_by_ref: task_by_ref}} = supervisor_state
      ) do
    {task, running_task_by_ref} = Map.pop(task_by_ref, ref)

    case task do
      nil ->
        Logger.error(fn ->
          "Unknown ref (#{inspect(ref)}) that is neither the catchup index" <>
            " nor a realtime index Task ref returned result (#{inspect(result)})"
        end)

      _ ->
        :ok
    end

    Process.demonitor(ref, [:flush])

    put_in(supervisor_state.realtime.task_by_ref, running_task_by_ref)
  end

  def handle_failure(
        {:DOWN, ref, :process, pid, reason},
        %BlockFetcher.Supervisor{realtime: %__MODULE__{task_by_ref: task_by_ref}} = supervisor_state
      ) do
    {task, running_task_by_ref} = Map.pop(task_by_ref, ref)

    case task do
      nil ->
        Logger.error(fn ->
          "Unknown ref (#{inspect(ref)}) that is neither the catchup index" <>
            " nor a realtime index Task ref reports unknown pid (#{pid}) DOWN due to reason (#{reason}})"
        end)

      _ ->
        Logger.error(fn ->
          "Realtime index stream exited with reason (#{inspect(reason)}).  " <>
            "The next realtime index task will fill the missing block " <>
            "if the lastest block number has not advanced by then or the catch up index will fill the missing block."
        end)
    end

    put_in(supervisor_state.realtime.task_by_ref, running_task_by_ref)
  end
end
