defmodule Explorer.Chain.Events.DBSender do
  @moduledoc """
  Sends events to Postgres.
  """
  alias Explorer.Repo
  alias Explorer.Utility.EventNotification

  def send_data(event_type) do
    payload = encode_payload({:chain_event, event_type})
    send_notify(payload)
  end

  def send_data(_event_type, :catchup, _event_data), do: :ok

  def send_data(event_type, broadcast_type, event_data) do
    payload = encode_payload({:chain_event, event_type, broadcast_type, event_data})

    with {:ok, %{id: event_notification_id}} <- save_event_notification(payload) do
      send_notify(to_string(event_notification_id))
    end
  end

  defp encode_payload(payload) do
    payload
    |> :erlang.term_to_binary([:compressed])
    |> Base.encode64()
  end

  defp send_notify(payload) do
    Repo.query!("select pg_notify('chain_event', $1::text);", [payload])
  end

  defp save_event_notification(event_data) do
    event_data
    |> EventNotification.new_changeset()
    |> Repo.insert()
  end
end
