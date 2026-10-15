# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.CreateTokenTransferPoisoningAttacks do
  use Ecto.Migration

  def change do
    create table(:token_transfer_poisoning_attacks, primary_key: false) do
      add(:block_hash, :bytea, null: false, primary_key: true)
      add(:log_index, :integer, null: false, primary_key: true)
      add(:transaction_hash, :bytea, null: true)
      add(:block_number, :bigint, null: false)
      # address ids as mapped by `address_ids_to_address_hashes`
      add(:token_contract_address_id, :bigint, null: false)
      add(:victim_address_id, :bigint, null: false)
      add(:mimic_address_id, :bigint, null: false)
      add(:issuer_address_id, :bigint, null: true)
      add(:score, :integer, null: false)
      add(:rules, {:array, :string}, null: false)
      add(:details, :map, null: false, default: %{})

      timestamps()
    end

    create(
      index(:token_transfer_poisoning_attacks, [:victim_address_id, "block_number DESC"],
        name: :token_transfer_poisoning_attacks_victim_block_number_index
      )
    )
  end
end
