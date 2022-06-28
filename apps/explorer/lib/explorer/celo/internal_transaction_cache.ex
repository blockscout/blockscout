defmodule Explorer.Celo.InternalTransactionCache do
  @moduledoc """
  Store internal transaction fetch results when blocks are not correctly indexed
  """
  use GenServer

  require Explorer.Celo.Telemetry, as: Telemetry

  @cache_time :timer.minutes(10)

  def store(block_number, itx) do
    pid = Process.whereis(__MODULE__)

    if pid do
      GenServer.cast(pid, {:store, block_number, itx})
    end
  end

  def get(block_number) do
    pid = Process.whereis(__MODULE__)

    if pid do
      GenServer.call(pid, {:get, block_number})
    end
  end

  def clear(block_number) do
    pid = Process.whereis(__MODULE__)

    if pid do
      GenServer.cast(pid, {:clear, block_number})
    end
  end

  def start_link([init_opts, gen_server_opts]) do
    start_link(init_opts, gen_server_opts)
  end

  def start_link(init_opts, gen_server_opts) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  def init(_opts) do
    {:ok,
     %{
       cache: %{},
       timers: %{}
     }}
  end

  def handle_cast({:store, block_number, itx}, _from, state) do
    state =
      state
      |> put_in([:cache, block_number], itx)
      |> put_in([:timers, block_number], Process.send_after(self(), {:clear, block_number}, @cache_time))

    {:noreply, state}
  end

  def handle_call({:get, block_number}, _from, %{cache: cache} = state) do
    itx = cache[block_number]

    if itx do
      Telemetry.event(:itx_cache_hit, %{block_number: block_number})
    end

    {:reply, itx, state}
  end

  defp remove_item(block_number, %{cache: cache, timers: timers} = state) do
    cache = Map.delete(cache, block_number)

    timers =
      if timers[block_number] do
        Process.cancel_timer(timers[block_number])
        Map.delete(timers, block_number)
      else
        timers
      end

    %{cache: cache, timers: timers}
  end

  def handle_cast({:clear, block_number}, _from, state) do
    {:noreply, remove_item(block_number, state)}
  end

  def handle_info({:clear, block_number}, _from, state) do
    {:noreply, remove_item(block_number, state)}
  end
end
