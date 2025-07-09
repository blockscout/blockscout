defmodule Indexer.Utils.EventNotificationsCleanerTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Utility.EventNotification
  alias Indexer.Utils.EventNotificationsCleaner

  import Ecto.Query

  setup do
    # Store original config
    original_config = Application.get_env(:indexer, EventNotificationsCleaner)

    # Restore original config after each test
    on_exit(fn ->
      Application.put_env(:indexer, EventNotificationsCleaner, original_config)
    end)

    :ok
  end

  describe "start_link/1" do
    test "starts the GenServer with the given name" do
      assert {:ok, pid} = EventNotificationsCleaner.start_link([])
      assert Process.alive?(pid)
      Process.exit(pid, :normal)
    end
  end

  describe "clean_up_event_notifications/0" do
    test "deletes notifications older than max_age" do
      # Create notifications with different timestamps
      old_time = DateTime.utc_now() |> DateTime.add(-2000, :millisecond)
      new_time = DateTime.utc_now() |> DateTime.add(-500, :millisecond)

      insert(:event_notification, data: "old_data", inserted_at: old_time)
      insert(:event_notification, data: "new_data", inserted_at: new_time)

      # Verify both notifications exist
      assert Repo.aggregate(EventNotification, :count) == 2

      # Set configuration for max_age of 1000ms
      config = Application.get_env(:indexer, EventNotificationsCleaner)
      Application.put_env(:indexer, EventNotificationsCleaner, Keyword.put(config, :max_age, 1000))

      assert {:ok, _pid} = EventNotificationsCleaner.start_link([])
      Process.sleep(500)

      # Verify only the old notification was deleted
      assert Repo.aggregate(EventNotification, :count) == 1
      remaining = Repo.one(from(n in EventNotification, select: n.data))
      assert remaining == "new_data"
    end

    test "deletes multiple old notifications" do
      old_time = DateTime.utc_now() |> DateTime.add(-2000, :millisecond)

      # Insert multiple old notifications
      insert_list(3, :event_notification, inserted_at: old_time)

      # Insert one new notification
      insert(:event_notification, data: "new_data")

      # Verify all notifications exist
      assert Repo.aggregate(EventNotification, :count) == 4

      # Set configuration
      config = Application.get_env(:indexer, EventNotificationsCleaner)
      Application.put_env(:indexer, EventNotificationsCleaner, Keyword.put(config, :max_age, 1000))

      assert {:ok, _pid} = EventNotificationsCleaner.start_link([])
      Process.sleep(500)

      # Verify only the new notification remains
      assert Repo.aggregate(EventNotification, :count) == 1
      remaining = Repo.one(from(n in EventNotification, select: n.data))
      assert remaining == "new_data"
    end

    test "does not delete notifications when none are old enough" do
      # Insert only new notifications
      insert_list(3, :event_notification)

      # Verify notifications exist
      assert Repo.aggregate(EventNotification, :count) == 3

      # Set configuration
      config = Application.get_env(:indexer, EventNotificationsCleaner)
      Application.put_env(:indexer, EventNotificationsCleaner, Keyword.put(config, :max_age, 1000))

      assert {:ok, _pid} = EventNotificationsCleaner.start_link([])
      Process.sleep(500)

      # Verify all notifications still exist
      assert Repo.aggregate(EventNotification, :count) == 3
    end
  end
end
