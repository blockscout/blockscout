defmodule Explorer.Repo.Migrations.AddTimestampToEventNotifications do
  use Ecto.Migration

  def change do
    execute("TRUNCATE event_notifications;")

    alter table(:event_notifications) do
      timestamps()
    end
  end
end
