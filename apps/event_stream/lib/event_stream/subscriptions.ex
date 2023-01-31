defmodule EventStream.Subscriptions do
  @moduledoc "Register a process to receive messages for a given set of events"

  alias Explorer.Chain.Events.Subscriber

  @subscribed_event_types [:celo_contract_event, :tracked_contract_event]
  @doc "Register current process to receive messages for all events defined in config"
  def subscribe do
    subscribe(@subscribed_event_types)
  end

  @doc "Register current process to receive message for given events"
  def subscribe(events) do
    events
    |> Enum.each(fn event ->
      Subscriber.to(event)
      Subscriber.to(event, :realtime)
    end)
  end
end
