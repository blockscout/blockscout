defmodule Indexer.Block.InvalidConsensus.Worker do
  @moduledoc """
  Finds blocks with invalid consensus and queues them up to be refetched. This
  process does this once, after the application starts up.

  A block has invalid consensus when it is referenced as the parent hash of a
  block with consensus while not having consensus (consensus=false). Only one
  block can have consensus at a given height (block number).
  """

  use GenServer

  require Logger

  alias Explorer.Chain
  alias Indexer.Block.Catchup.Fetcher
  alias Indexer.Block.InvalidConsensus.TaskSupervisor

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(init_arguments, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, init_arguments, gen_server_options)
  end

  def init(opts) do
    sup_pid = Keyword.fetch!(opts, :supervisor)
    retry_interval = Keyword.get(opts, :retry_interval, 10_000)

    send(self(), :scan)

    state = %{
      block_numbers: [],
      retry_interval: retry_interval,
      sup_pid: sup_pid,
      task_ref: nil
    }

    {:ok, state}
  end

  def handle_info(:scan, state) do
    block_numbers = Chain.list_block_numbers_with_invalid_consensus()

    case block_numbers do
      [] ->
        Supervisor.stop(state.sup_pid, :normal)
        {:noreply, state}

      block_numbers ->
        Process.send_after(self(), :push_front_blocks, state.retry_interval)
        {:noreply, %{state | block_numbers: block_numbers}}
    end
  end

  def handle_info(:push_front_blocks, %{block_numbers: block_numbers} = state) do
    %Task{ref: ref} = async_push_front(block_numbers)
    {:noreply, %{state | task_ref: ref}}
  end

  def handle_info({ref, :ok}, %{task_ref: ref, sup_pid: sup_pid}) do
    Process.demonitor(ref, [:flush])
    Supervisor.stop(sup_pid, :normal)
    {:stop, :shutdown}
  end

  def handle_info({ref, {:error, reason}}, %{task_ref: ref, retry_interval: millis} = state) do
    Logger.error(fn -> inspect(reason) end)

    Process.demonitor(ref, [:flush])
    Process.send_after(self(), :push_front_blocks, millis)

    {:noreply, %{state | task_ref: nil}}
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{task_ref: ref, retry_interval: millis} = state) do
    Process.send_after(self(), :push_front_blocks, millis)
    {:noreply, %{state | task_ref: nil}}
  end

  defp async_push_front(block_numbers) do
    Task.Supervisor.async_nolink(TaskSupervisor, Fetcher, :push_front, [block_numbers])
  end
end
