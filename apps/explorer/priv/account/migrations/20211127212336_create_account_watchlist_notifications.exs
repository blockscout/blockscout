defmodule Explorer.Repo.Account.Migrations.CreateAccountWatchlistNotifications do
  use Ecto.Migration

  def change do
    create table(:account_watchlist_notifications) do
      add(:watchlist_address_id, references(:account_watchlist_addresses, on_delete: :delete_all))

      add(:transaction_hash, :bytea)

      add(:from_address_hash, :bytea)

      add(:to_address_hash, :bytea)

      add(:direction, :string)
      add(:name, :string)
      add(:type, :string)
      add(:method, :string)
      add(:block_number, :integer)
      add(:amount, :decimal)
      add(:tx_fee, :decimal)
      add(:viewed_at, :utc_datetime_usec)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:account_watchlist_notifications, [:watchlist_address_id]))
    create(index(:account_watchlist_notifications, [:transaction_hash]))
    create(index(:account_watchlist_notifications, [:from_address_hash]))
    create(index(:account_watchlist_notifications, [:to_address_hash]))
  end
end
