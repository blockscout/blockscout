defmodule BlockScoutWeb.RealtimeEventHandlers.TokenTransfer do
  @moduledoc """
  Subscribing process for token transfer broadcast events from realtime.
  """

  use GenServer

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.Events.Subscriber

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    Subscriber.to(:token_transfers, :realtime)
    {:ok, []}
  end

  @impl true
  def handle_info(event, state) do
    Notifier.handle_event(event)
    {:noreply, state}
  end
end
