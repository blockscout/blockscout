defmodule Explorer.Repo.Account.Migrations.AccountV2 do
  use Ecto.Migration

  def change do
    alter table(:account_identities) do
      remove(:name)
      remove(:nickname)
      add(:otp_sent_at, :"timestamp without time zone", null: true)
    end

    alter table(:account_custom_abis) do
      add(:user_created, :boolean, default: true)
    end

    alter table(:account_tag_addresses) do
      add(:user_created, :boolean, default: true)
    end

    alter table(:account_tag_transactions) do
      add(:user_created, :boolean, default: true)
    end

    alter table(:account_watchlist_addresses) do
      add(:user_created, :boolean, default: true)
    end

    drop_if_exists(unique_index(:account_custom_abis, [:identity_id, :address_hash_hash]))
    drop_if_exists(unique_index(:account_tag_addresses, [:identity_id, :address_hash_hash]))
    drop_if_exists(unique_index(:account_tag_transactions, [:identity_id, :tx_hash_hash]))

    drop_if_exists(
      unique_index(:account_watchlist_addresses, [:watchlist_id, :address_hash_hash],
        name: "unique_watchlist_id_address_hash_hash_index"
      )
    )

    create(unique_index(:account_custom_abis, [:identity_id, :address_hash_hash], where: "user_created = true"))

    create(unique_index(:account_tag_addresses, [:identity_id, :address_hash_hash], where: "user_created = true"))

    create(unique_index(:account_tag_transactions, [:identity_id, :tx_hash_hash], where: "user_created = true"))

    create(
      unique_index(:account_watchlist_addresses, [:watchlist_id, :address_hash_hash],
        name: "unique_watchlist_id_address_hash_hash_index",
        where: "user_created = true"
      )
    )
  end
end
