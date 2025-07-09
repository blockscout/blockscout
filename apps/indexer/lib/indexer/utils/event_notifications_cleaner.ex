defmodule Indexer.Utils.EventNotificationsCleaner do
  @moduledoc """
  Module is responsible for cleaning up event notifications from the database.
  """

  alias Explorer.Repo
  alias Explorer.Utility.EventNotification

  import Ecto.Query

  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    Process.send(self(), :clean_up_event_notifications, [])
    {:ok, args}
  end

  def handle_info(:clean_up_event_notifications, state) do
    clean_up_event_notifications()
    Process.send_after(self(), :clean_up_event_notifications, interval())
    {:noreply, state}
  end

  defp clean_up_event_notifications do
    {count, _} =
      EventNotification
      |> where([en], en.inserted_at < ago(^max_age(), "millisecond"))
      |> Repo.delete_all()

    Logger.info("Deleted #{count} event notifications")
  end

  defp max_age do
    config()[:max_age]
  end

  defp interval do
    config()[:interval]
  end

  defp config do
    Application.get_env(:indexer, __MODULE__)
  end
end
