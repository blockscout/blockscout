defmodule Explorer.Repo.Migrations.AddTimestampToEventNotifications do
  use Ecto.Migration

  def change do
    alter table(:event_notifications) do
      timestamps(null: true)
    end
  end
end
