defmodule ExplorerWeb.EventHandler do
  use GenServer
  alias Explorer.Chain
  alias ExplorerWeb.Notifier

  # Client

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # Server

  def init([]) do
    Chain.subscribe_to_events(:blocks)
    {:ok, []}
  end

  def handle_info({:chain_event, :blocks, blocks}, state) do
    Notifier.block_confirmations(Enum.max_by(blocks, & &1.number).number)
    {:noreply, state}
  end

  def handle_info(_event, state) do
    {:noreply, state}
  end
end
