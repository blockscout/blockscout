defmodule Explorer.Chain.Events.Listener do
  @moduledoc """
  Listens and publishes events from PG
  """

  use GenServer

  alias Explorer.Repo
  alias Explorer.Utility.EventNotification
  alias Postgrex.Notifications

  def start_link(_) do
    GenServer.start_link(__MODULE__, "chain_event", name: __MODULE__)
  end

  def init(channel) do
    {:ok, pid} =
      :explorer
      |> Application.get_env(Explorer.Repo)
      |> Notifications.start_link()

    ref = Notifications.listen!(pid, channel)

    {:ok, {pid, ref, channel}}
  end

  def handle_info({:notification, _pid, _ref, _topic, payload}, state) do
    payload
    |> expand_payload()
    |> decode_payload!()
    |> broadcast()

    {:noreply, state}
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

  defp broadcast({:chain_event, event_type} = event) do
    Registry.dispatch(Registry.ChainEvents, event_type, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, event)
      end
    end)
  end

  defp broadcast({:chain_event, event_type, broadcast_type, _data} = event) do
    Registry.dispatch(Registry.ChainEvents, {event_type, broadcast_type}, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, event)
      end
    end)
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
