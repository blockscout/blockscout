defmodule Indexer.Temporary.UncatalogedTokenTransfers do
  @moduledoc """
  Catalogs token transfer logs missing an accompanying token transfer record.

  Missed token transfers happen due to formats that aren't supported at the time
  they were parsed during main indexing. Updated the parser and rebooting will allow
  this process to properly catalog those missed token transfers.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Explorer.Chain
  alias Indexer.Block.Catchup.Fetcher
  alias Indexer.Temporary.UncatalogedTokenTransfers

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
    {:ok, block_numbers} = Chain.uncataloged_token_transfer_block_numbers()

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
    case reason do
      :queue_unavailable -> :ok
      _ -> Logger.error(fn -> inspect(reason) end)
    end

    Process.demonitor(ref, [:flush])
    Process.send_after(self(), :push_front_blocks, millis)

    {:noreply, %{state | task_ref: nil}}
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{task_ref: ref, retry_interval: millis} = state) do
    Process.send_after(self(), :push_front_blocks, millis)
    {:noreply, %{state | task_ref: nil}}
  end

  defp async_push_front(block_numbers) do
    Task.Supervisor.async_nolink(UncatalogedTokenTransfers.TaskSupervisor, Fetcher, :push_front, [block_numbers])
  end
end
