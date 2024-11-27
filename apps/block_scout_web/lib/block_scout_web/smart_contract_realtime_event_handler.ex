defmodule BlockScoutWeb.SmartContractRealtimeEventHandler do
  @moduledoc """
  Subscribing process for smart contract verification related broadcast events from realtime.
  """

  use GenServer

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.Events.Subscriber

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    Subscriber.to(:contract_verification_result, :on_demand)
    Subscriber.to(:smart_contract_was_verified, :on_demand)
    Subscriber.to(:smart_contract_was_not_verified, :on_demand)
    Subscriber.to(:eth_bytecode_db_lookup_started, :on_demand)
    {:ok, []}
  end

  @impl true
  def handle_info(event, state) do
    Notifier.handle_event(event)
    {:noreply, state}
  end
end
