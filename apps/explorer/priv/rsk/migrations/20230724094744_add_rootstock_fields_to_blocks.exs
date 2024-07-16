defmodule Explorer.Repo.RSK.Migrations.AddRootstockFieldsToBlocks do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:minimum_gas_price, :decimal)
      add(:bitcoin_merged_mining_header, :bytea)
      add(:bitcoin_merged_mining_coinbase_transaction, :bytea)
      add(:bitcoin_merged_mining_merkle_proof, :bytea)
      add(:hash_for_merged_mining, :bytea)
    end
  end
end
