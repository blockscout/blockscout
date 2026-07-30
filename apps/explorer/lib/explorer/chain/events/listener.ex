# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Events.Listener do
  @moduledoc """
  Listens and publishes events from PG
  """

  use GenServer

  import Ecto.Query

  alias Explorer.Repo.ConfigHelper
  alias Explorer.Repo.EventNotifications, as: EventNotificationsRepo
  alias Explorer.Utility.EventNotification
  alias Postgrex.Notifications

  def start_link(_) do
    GenServer.start_link(__MODULE__, "chain_event", name: __MODULE__)
  end

  def init(channel) do
    {:ok, pid} =
      :explorer
      |> Application.get_env(EventNotificationsRepo)
      |> Keyword.merge(listener_db_parameters())
      |> Notifications.start_link()

    ref = Notifications.listen!(pid, channel)

    {:ok, {pid, ref, channel}}
  end

  def handle_info({:notification, _pid, _ref, _topic, payload}, state) do
    [payload]
    |> drain_notifications(Application.get_env(:explorer, __MODULE__)[:max_batch_size] - 1)
    |> expand_payloads()
    |> Enum.each(fn expanded_payload ->
      expanded_payload
      |> decode_payload!()
      |> broadcast()
    end)

    {:noreply, state}
  end

  defp drain_notifications(payloads, 0), do: Enum.reverse(payloads)

  defp drain_notifications(payloads, count) do
    receive do
      {:notification, _pid, _ref, _topic, payload} -> drain_notifications([payload | payloads], count - 1)
    after
      0 -> Enum.reverse(payloads)
    end
  end

  defp expand_payloads(payloads) do
    parsed_payloads = Enum.map(payloads, &parse_payload/1)

    id_to_data =
      parsed_payloads
      |> Enum.flat_map(fn
        {:id, id} -> [id]
        {:data, _data} -> []
      end)
      |> fetch_event_notifications()

    Enum.flat_map(parsed_payloads, fn
      {:id, id} -> id_to_data |> Map.get(id) |> List.wrap()
      {:data, data} -> [data]
    end)
  end

  defp parse_payload(payload) do
    case Integer.parse(payload) do
      {event_notification_id, ""} -> {:id, event_notification_id}
      _ -> {:data, payload}
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

  defp fetch_event_notifications([]), do: %{}

  defp fetch_event_notifications(ids) do
    EventNotification
    |> where([en], en.id in ^ids)
    |> select([en], {en.id, en.data})
    |> EventNotificationsRepo.all()
    |> Map.new()
  end

  defp listener_db_parameters do
    listener_db_url = Application.get_env(:explorer, EventNotificationsRepo)[:url]
    ConfigHelper.extract_parameters(listener_db_url)
  end
end
