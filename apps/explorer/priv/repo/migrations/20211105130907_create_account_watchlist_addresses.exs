defmodule Explorer.Repo.Migrations.CreateAccountWatchlistAddresses do
  use Ecto.Migration

  def change do
    create table(:account_watchlist_addresses) do
      add(:name, :string)
      add(:address_hash, references(:addresses, column: :hash, type: :bytea, on_delete: :delete_all))
      add(:watchlist_id, references(:account_watchlists, on_delete: :delete_all))

      timestamps()
    end

    create(index(:account_watchlist_addresses, [:watchlist_id]))
    create(index(:account_watchlist_addresses, [:address_hash]))
  end
end
