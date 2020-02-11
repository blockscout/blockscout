defmodule Explorer.Repo.Migrations.CreateCeloVoterRewards do
  use Ecto.Migration

  def change do
    create table(:celo_voter_rewards) do
      add(:block_hash, :bytea, null: false)
      add(:log_index, :integer, null: false)
      add(:block_number, :integer, null: false)
      add(:reward, :numeric, precision: 100)
      add(:active_votes, :numeric, precision: 100)
      add(:address_hash, :bytea, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_voter_rewards, [:block_hash, :log_index], unique: true))

  end
end
