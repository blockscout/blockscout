defmodule BlockScoutWeb.StakingEventHandler do
  @moduledoc """
  Subscribing process for broadcast events from staking app.
  """

  use GenServer

  alias BlockScoutWeb.Endpoint
  alias Explorer.Chain.Events.Subscriber

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    Subscriber.to(:staking_update, :realtime)
    {:ok, []}
  end

  @impl true
  def handle_info({:chain_event, :staking_update, :realtime, data}, state) do
    Endpoint.broadcast("stakes:staking_update", "staking_update", data)
    {:noreply, state}
  end
end
