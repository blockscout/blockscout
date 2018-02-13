defmodule Explorer.Servers.ChainStatistics do
  @moduledoc "Stores the latest chain statistics."

  use GenServer

  alias Explorer.Chain

  @interval 1_000

  def fetch do
    case GenServer.whereis(__MODULE__) do
      nil -> Chain.fetch()
      pid -> GenServer.call(pid, :fetch)
    end
  end
  def start_link, do: start_link(%Chain{})
  def start_link(%Chain{} = chain) do
    GenServer.start_link(__MODULE__, chain, name: __MODULE__)
  end

  def init(chain) do
    refresh()
    {:ok, chain}
  end

  def refresh, do: refresh(@interval)
  def refresh(interval), do: Process.send_after(self(), :refresh, interval)

  def handle_info(:refresh, _) do
    chain = Chain.fetch()
    refresh()
    {:noreply, chain}
  end
  def handle_info(_, tasks), do: {:noreply, tasks}
  def handle_call(:fetch, _, chain), do: {:reply, chain, chain}
  def handle_call(_, _, chain), do: {:noreply, chain}
end
