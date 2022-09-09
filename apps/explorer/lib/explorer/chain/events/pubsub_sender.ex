defmodule Explorer.Chain.Events.PubSubSender do
  @moduledoc """
  Sends events via Phoenix.PubSub / PG2
  """
  require Logger
  alias Explorer.Celo.Telemetry
  alias Phoenix.PubSub

  @max_payload 7500
  @pubsub_topic "chain_event"
  @pubsub_name :chain_pubsub

  def send_data(event_type) do
    payload = encode_payload({:chain_event, event_type})
    send_notify(payload)
  end

  def send_data(_event_type, :catchup, _event_data), do: :ok

  def send_data(event_type, broadcast_type, event_data) do
    payload = encode_payload({:chain_event, event_type, broadcast_type, event_data})
    send_notify(payload)
  end

  defp encode_payload(payload) do
    payload
    |> :erlang.term_to_binary([:compressed])
  end

  defp send_notify(payload) do
    payload_size = byte_size(payload)

    if payload_size < @max_payload do
      PubSub.broadcast(@pubsub_name, @pubsub_topic, {:chain_event, payload})
      Telemetry.event(:chain_event_send, %{payload_size: payload_size})
    else
      Logger.warn("Notification can't be sent, payload size #{payload_size} exceeds the limit of #{@max_payload}.")
    end
  end
end
