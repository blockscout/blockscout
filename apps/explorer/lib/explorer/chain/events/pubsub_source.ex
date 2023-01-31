defmodule Explorer.Chain.Events.PubSubSource do
  @moduledoc "Source of chain events via pg_notify"

  alias Explorer.Celo.Telemetry
  alias Phoenix.PubSub

  @channel "chain_event"
  @pubsub_name :chain_pubsub

  def setup_source do
    PubSub.subscribe(@pubsub_name, @channel)

    %{pubsub_name: @pubsub_name, topic: @channel}
  end

  def handle_source_msg({:chain_event, payload}) do
    payload
    |> decode_payload!()
    |> tap(fn {:chain_event, type, _broadcast_type, _event_data} ->
      Telemetry.event(:chain_event_receive, %{type: type, payload_size: byte_size(payload)})
    end)
  end

  # sobelow_skip ["Misc.BinToTerm"]
  defp decode_payload!(payload) do
    payload
    |> :erlang.binary_to_term()
  end
end
