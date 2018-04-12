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

  def start_link, do: start_link(true)

  def start_link(refresh) do
    GenServer.start_link(__MODULE__, refresh, name: __MODULE__)
  end

  def init(true) do
    {:noreply, chain} = handle_cast({:update, Chain.fetch()}, %Chain{})
    {:ok, chain}
  end

  def init(false), do: {:ok, Chain.fetch()}

  def handle_info(:refresh, %Chain{} = chain) do
    Task.start_link(fn ->
      GenServer.cast(__MODULE__, {:update, Chain.fetch()})
    end)

    {:noreply, chain}
  end

  def handle_info(_, %Chain{} = chain), do: {:noreply, chain}
  def handle_call(:fetch, _, %Chain{} = chain), do: {:reply, chain, chain}
  def handle_call(_, _, %Chain{} = chain), do: {:noreply, chain}

  def handle_cast({:update, %Chain{} = chain}, %Chain{} = _) do
    Process.send_after(self(), :refresh, @interval)
    {:noreply, chain}
  end

  def handle_cast(_, %Chain{} = chain), do: {:noreply, chain}
end
