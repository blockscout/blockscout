defmodule Explorer.Chain.Events.PubSubSource do
  @moduledoc "Source of chain events via pg_notify"

  alias Explorer.Celo.Telemetry
  alias Phoenix.PubSub

  @channel "chain_event"

  def setup_source do
    PubSub.subscribe(:chain_pubsub, @channel)

    %{pubsub_name: :chain_pubsub, topic: @channel}
  end

  def handle_source_msg({:chain_event, payload}) do
    Telemetry.event(:chain_event_receive, %{payload_size: byte_size(payload)})

    payload
    |> decode_payload!()
  end

  # sobelow_skip ["Misc.BinToTerm"]
  defp decode_payload!(payload) do
    payload
    |> :erlang.binary_to_term()
  end
end
