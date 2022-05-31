defmodule Explorer.Repo.Migrations.AddCeloElectionRewards do
  use Ecto.Migration

  def change do
    create table(:celo_election_rewards, primary_key: false) do
      add(:account_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:associated_account_hash, references(:celo_account, column: :address, type: :bytea), null: false)
      add(:amount, :numeric, precision: 100, null: false)
      add(:block_number, :integer, null: false)
      add(:block_timestamp, :utc_datetime_usec, null: false)
      add(:reward_type, :string, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:celo_election_rewards, [:account_hash, :reward_type, :block_number, :associated_account_hash]))
  end
end
