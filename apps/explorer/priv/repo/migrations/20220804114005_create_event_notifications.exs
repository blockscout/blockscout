defmodule Explorer.Repo.Migrations.CreateEventNotifications do
  use Ecto.Migration

  def change do
    create table(:event_notifications) do
      add(:data, :text, null: false)
    end
  end
end
