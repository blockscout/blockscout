defmodule Explorer.Chain.Events.SimpleSender do
  @moduledoc """
  Publishes events through Registry without intermediate levels.
  """

  def send_data(event_type, broadcast_type, event_data) do
    Registry.dispatch(Registry.ChainEvents, {event_type, broadcast_type}, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, {:chain_event, event_type, broadcast_type, event_data})
      end
    end)
  end

  def send_data(event_type) do
    Registry.dispatch(Registry.ChainEvents, event_type, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, {:chain_event, event_type})
      end
    end)
  end
end
