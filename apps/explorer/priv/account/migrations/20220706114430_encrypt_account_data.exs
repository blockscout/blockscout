defmodule Explorer.Repo.Account.Migrations.EncryptAccountData do
  use Ecto.Migration

  def change do
    alter table(:account_identities) do
      add(:encrypted_uid, :binary)
      add(:uid_hash, :binary)
      add(:encrypted_email, :binary)
      add(:encrypted_name, :binary)
      add(:encrypted_nickname, :binary, null: true)
      add(:encrypted_avatar, :binary, null: true)
    end

    # alter table(:account_watchlists) do
    #   add(:encrypted_name, :binary)
    # end

    alter table(:account_custom_abis) do
      add(:address_hash_hash, :binary)
      add(:encrypted_address_hash, :binary)
      add(:encrypted_name, :binary)
    end

    alter table(:account_tag_addresses) do
      add(:address_hash_hash, :binary)
      add(:encrypted_name, :binary)
      add(:encrypted_address_hash, :binary)
    end

    alter table(:account_tag_transactions) do
      add(:tx_hash_hash, :binary)
      add(:encrypted_name, :binary)
      add(:encrypted_tx_hash, :binary)
    end

    alter table(:account_watchlist_addresses) do
      add(:address_hash_hash, :binary)
      add(:encrypted_name, :binary)
      add(:encrypted_address_hash, :binary)
    end

    alter table(:account_watchlist_notifications) do
      add(:encrypted_name, :binary)
      add(:encrypted_subject, :binary, null: true)
      add(:encrypted_from_address_hash, :binary)
      add(:encrypted_to_address_hash, :binary)
      add(:encrypted_transaction_hash, :binary)
      add(:subject_hash, :binary, null: true)
      add(:from_address_hash_hash, :binary, null: true)
      add(:to_address_hash_hash, :binary, null: true)
      add(:transaction_hash_hash, :binary, null: true)
    end
  end
end
