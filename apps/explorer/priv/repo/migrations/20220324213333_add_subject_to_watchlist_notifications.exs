defmodule Explorer.Repo.Migrations.AddSubjectToWatchlistNotifications do
  use Ecto.Migration

  def change do
    alter table(:account_watchlist_notifications) do
      add(:subject, :string, null: true)
    end
  end
end
