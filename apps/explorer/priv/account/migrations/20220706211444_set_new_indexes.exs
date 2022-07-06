defmodule Explorer.Repo.Account.Migrations.SetNewIndexes do
  use Ecto.Migration

  def change do
    drop_if_exists(unique_index(:account_tag_addresses, [:identity_id, :address_hash]))
    drop_if_exists(unique_index(:account_tag_transactions, [:identity_id, :tx_hash]))
    drop_if_exists(unique_index(:account_watchlist_addresses, [:watchlist_id, :address_hash]))
    drop_if_exists(unique_index(:account_custom_abis, [:identity_id, :address_hash]))

    drop_if_exists(index(:account_watchlist_notifications, [:transaction_hash]))
    drop_if_exists(index(:account_watchlist_notifications, [:from_address_hash]))
    drop_if_exists(index(:account_watchlist_notifications, [:to_address_hash]))

    drop_if_exists(unique_index(:account_identities, [:uid]))

    drop_if_exists(index(:account_tag_addresses, [:address_hash]))
    drop_if_exists(index(:account_tag_transactions, [:tx_hash]))

    drop_if_exists(index(:account_watchlist_addresses, [:address_hash]))

    create(unique_index(:account_tag_addresses, [:identity_id, :address_hash_hash]))
    create(unique_index(:account_tag_transactions, [:identity_id, :tx_hash_hash]))
    create(unique_index(:account_watchlist_addresses, [:watchlist_id, :address_hash_hash]))
    create(unique_index(:account_custom_abis, [:identity_id, :address_hash_hash]))

    create(index(:account_watchlist_notifications, [:transaction_hash_hash]))
    create(index(:account_watchlist_notifications, [:from_address_hash_hash]))
    create(index(:account_watchlist_notifications, [:to_address_hash_hash]))

    create(unique_index(:account_identities, [:uid_hash]))

    create(index(:account_tag_addresses, [:address_hash_hash]))
    create(index(:account_tag_transactions, [:tx_hash_hash]))

    create(index(:account_watchlist_addresses, [:address_hash_hash]))
  end
end
