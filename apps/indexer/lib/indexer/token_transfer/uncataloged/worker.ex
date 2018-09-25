defmodule Indexer.TokenTransfer.Uncataloged.Worker do
  @moduledoc """
  Catalogs token tranfer logs missing an accompanying token transfer record.

  Missed token transfers happen due to formats that aren't supported at the time
  they were parsed during main indexing. Updated the parser and rebooting will allow
  this process to properly catalog those missed token transfers.
  """

  use GenServer

  alias Explorer.Chain
  alias Indexer.Block.Catchup.Fetcher
  alias Indexer.TokenTransfer.Uncataloged

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    sup_pid = Keyword.fetch!(opts, :supervisor)
    retry_interval = Keyword.get(opts, :retry_interval, 30_000)

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
    {:ok, block_numbers} = Chain.uncataloged_token_transfer_block_numbers()

    case block_numbers do
      [] ->
        Supervisor.stop(state.sup_pid, :normal)
        {:noreply, state}

      block_numbers ->
        Process.send_after(self(), :enqueue_blocks, state.retry_interval)
        {:noreply, %{state | block_numbers: block_numbers}}
    end
  end

  def handle_info(:enqueue_blocks, %{block_numbers: block_numbers} = state) do
    %Task{ref: ref} = async_enqueue(block_numbers)
    {:noreply, %{state | task_ref: ref}}
  end

  def handle_info({ref, :ok}, %{task_ref: ref, sup_pid: sup_pid}) do
    Process.demonitor(ref, [:flush])
    Supervisor.stop(sup_pid, :normal)
    {:stop, :shutdown}
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{task_ref: ref, retry_interval: millis} = state) do
    Process.send_after(self(), :enqueue_blocks, millis)
    {:noreply, %{state | task_ref: nil}}
  end

  defp async_enqueue(block_numbers) do
    Task.Supervisor.async_nolink(Uncataloged.TaskSupervisor, Fetcher, :enqueue, [block_numbers])
  end
end
