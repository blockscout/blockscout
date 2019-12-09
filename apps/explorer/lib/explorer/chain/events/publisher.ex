defmodule Explorer.Chain.Events.Publisher do
  @moduledoc """
  Publishes events related to the Chain context.
  """
  @sender Application.get_env(:explorer, :realtime_events_sender)

  @allowed_events ~w(addresses address_coin_balances blocks block_rewards internal_transactions token_transfers transactions contract_verification_result)a

  def broadcast(_data, false), do: :ok

  def broadcast(data, broadcast_type) do
    for {event_type, event_data} <- data, event_type in @allowed_events do
      send_data(event_type, broadcast_type, event_data)
    end
  end

  @spec broadcast(atom()) :: :ok
  def broadcast(event_type) do
    send_data(event_type)
    :ok
  end

  @max_payload 7500

  defp send_data(event_type) do
    payload = encode_payload({:chain_event, event_type})

    if byte_size(payload) < @max_payload do
      @sender.send_notify(payload)
    end
  end

  # The :catchup type of event is not being consumed right now.
  # To avoid a large number of unread messages in the `mailbox` the dispatch of
  # these type of events is disabled for now.
  defp send_data(_event_type, :catchup, _event_data), do: :ok

  defp send_data(event_type, broadcast_type, event_data) do
    payload = encode_payload({:chain_event, event_type, broadcast_type, event_data})

    if byte_size(payload) < @max_payload do
      @sender.send_notify(payload)
    end
  end

  defp encode_payload(payload) do
    payload
    |> :erlang.term_to_binary([:compressed])
    |> Base.encode64()
  end
end
