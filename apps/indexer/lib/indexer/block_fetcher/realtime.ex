defmodule Indexer.BlockFetcher.Realtime do
  @moduledoc """
  Fetches and indexes block ranges from latest block forward.
  """

  require Logger

  import Indexer.BlockFetcher, only: [stream_import: 4]

  alias Indexer.{BlockFetcher, Sequence}

  @doc """
  Starts `task/1` and puts it in `t:Indexer.BlockFetcher.t/0` `realtime_task_by_ref`.
  """
  def put(%BlockFetcher{} = state) do
    %Task{ref: ref} = realtime_task = Task.Supervisor.async_nolink(Indexer.TaskSupervisor, __MODULE__, :task, [state])

    put_in(state.realtime_task_by_ref[ref], realtime_task)
  end

  def task(%BlockFetcher{json_rpc_named_arguments: json_rpc_named_arguments} = state) do
    {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)
    {:ok, seq} = Sequence.start_link(first: latest_block_number, step: 2)
    stream_import(state, seq, :realtime_index, max_concurrency: 1)
  end

  def handle_success({ref, :ok = result}, %BlockFetcher{realtime_task_by_ref: realtime_task_by_ref} = state) do
    {realtime_task, running_realtime_task_by_ref} = Map.pop(realtime_task_by_ref, ref)

    case realtime_task do
      nil ->
        Logger.error(fn ->
          "Unknown ref (#{inspect(ref)}) that is neither the catchup index" <>
            " nor a realtime index Task ref returned result (#{inspect(result)})"
        end)

      _ ->
        :ok
    end

    Process.demonitor(ref, [:flush])

    %BlockFetcher{state | realtime_task_by_ref: running_realtime_task_by_ref}
  end

  def handle_failure(
        {:DOWN, ref, :process, pid, reason},
        %BlockFetcher{realtime_task_by_ref: realtime_task_by_ref} = state
      ) do
    {realtime_task, running_realtime_task_by_ref} = Map.pop(realtime_task_by_ref, ref)

    case realtime_task do
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

    %BlockFetcher{state | realtime_task_by_ref: running_realtime_task_by_ref}
  end
end
