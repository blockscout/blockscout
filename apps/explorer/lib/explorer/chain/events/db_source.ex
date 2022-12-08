defmodule Explorer.Chain.Events.DBSource do
  @moduledoc "Source of chain events via pg_notify"

  alias Explorer.Repo
  alias Explorer.Utility.EventNotification
  alias Postgrex.Notifications

  @channel "chain_event"

  def setup_source do
    {:ok, pid} =
      :explorer
      |> Application.get_env(Explorer.Repo)
      |> Notifications.start_link()

    ref = Notifications.listen!(pid, @channel)

    %{dbsource_pid: pid, channel_ref: ref}
  end

  def handle_source_msg({:notification, _pid, _ref, _topic, payload}) do
    payload
    |> expand_payload()
    |> decode_payload!()
  end

  defp expand_payload(payload) do
    case Integer.parse(payload) do
      {event_notification_id, ""} -> fetch_and_delete_event_notification(event_notification_id)
      _ -> payload
    end
  end

  # sobelow_skip ["Misc.BinToTerm"]
  defp decode_payload!(payload) do
    payload
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end

  defp fetch_and_delete_event_notification(id) do
    case Repo.get(EventNotification, id) do
      nil ->
        nil

      %{data: data} = notification ->
        Repo.delete(notification)
        data
    end
  end
end
