defmodule Explorer.Repo.Migrations.CreateInternalTransactionsAddressPlaceholders do
  use Ecto.Migration

  def change do
    create table(:deleted_internal_transactions_address_placeholders, primary_key: false) do
      add(:address_id, references(:address_ids_to_address_hashes, column: :address_id, type: :bigint),
        primary_key: true
      )

      add(:block_number, :bigint, primary_key: true)
      add(:count_tos, :smallint, null: false)
      add(:count_froms, :smallint, null: false)
    end
  end
end
