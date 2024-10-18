defmodule Explorer.Repo.Account.Migrations.AddWatchlistIdColumn do
  use Ecto.Migration

  def change do
    execute("""
    ALTER TABLE account_watchlist_notifications
      DROP CONSTRAINT account_watchlist_notifications_watchlist_address_id_fkey;
    """)

    alter table(:account_watchlist_notifications) do
      add(:watchlist_id, :bigserial)
    end

    create(index(:account_watchlist_notifications, [:watchlist_id]))

    execute("""
    UPDATE account_watchlist_notifications awn
    SET watchlist_id = awa.watchlist_id
    FROM account_watchlist_addresses awa
    WHERE awa.id = awn.watchlist_address_id
    """)
  end
end
