defmodule Explorer.Repo.Migrations.AddUniqueConstraints do
  use Ecto.Migration

  def change do
    create(unique_index(:account_tag_addresses, [:identity_id, :address_hash]))
    create(unique_index(:account_tag_transactions, [:identity_id, :tx_hash]))
    create(unique_index(:account_watchlist_addresses, [:watchlist_id, :address_hash]))
  end
end
