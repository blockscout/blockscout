defmodule Explorer.Chain.Events.DBSender do
  @moduledoc """
  Sends events to Postgres.
  """
  alias Explorer.Repo
  require Logger

  @max_payload 7500

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
    |> Base.encode64()
  end

  defp send_notify(payload) do
    payload_size = byte_size(payload)

    if payload_size < @max_payload do
      Repo.query!("select pg_notify('chain_event', $1::text);", [payload])
    else
      Logger.warn("Notification can't be sent, payload size #{payload_size} exceeds the limit of #{@max_payload}.")
    end
  end
end
