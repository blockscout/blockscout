defmodule Explorer.Repo.Zilliqa.Migrations.CreateZilliqaStakers do
  use Ecto.Migration

  def change do
    create table(:zilliqa_stakers, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:index, :integer)
      add(:balance, :decimal, null: false)
      add(:peer_id, :bytea)
      add(:control_address_hash, :bytea)
      add(:reward_address_hash, :bytea)
      add(:signing_address_hash, :bytea)

      add(:added_at_block_number, :integer, null: false)
      add(:stake_updated_at_block_number, :integer, null: false)
      timestamps()
    end
  end
end
