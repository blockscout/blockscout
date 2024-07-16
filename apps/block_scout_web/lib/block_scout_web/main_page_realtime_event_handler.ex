defmodule BlockScoutWeb.MainPageRealtimeEventHandler do
  @moduledoc """
  Subscribing process for main page broadcast events from realtime.
  """

  use GenServer

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Counters.Helper

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    Helper.create_cache_table(:last_broadcasted_block)
    Subscriber.to(:blocks, :realtime)
    Subscriber.to(:transactions, :realtime)
    {:ok, []}
  end

  @impl true
  def handle_info(event, state) do
    Notifier.handle_event(event)
    {:noreply, state}
  end
end
