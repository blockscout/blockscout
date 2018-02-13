defmodule Explorer.Servers.ChainStatistics do
  @moduledoc "Stores the latest chain statistics."

  use GenServer

  alias Explorer.Chain

  @interval 1_000

  def fetch do
    case GenServer.whereis(__MODULE__) do
      nil -> Chain.fetch()
      _ -> GenServer.call(__MODULE__, :fetch)
    end
  end

  def start_link, do: start_link(nil)
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    refresh()
    {:ok, %Chain{}}
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
