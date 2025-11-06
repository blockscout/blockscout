defmodule Explorer.Repo.Celo.Migrations.CreateCeloAggregatedElectionRewards do
  use Ecto.Migration

  def change do
    create table(:celo_aggregated_election_rewards, primary_key: false) do
      add(:sum, :numeric, precision: 100, null: false)
      add(:count, :integer, null: false)
      add(:type, :celo_election_reward_type, null: false, primary_key: true)

      add(
        :epoch_number,
        references(
          :celo_epochs,
          column: :number,
          on_delete: :delete_all
        ),
        null: false,
        primary_key: true
      )

      timestamps()
    end

    # Index for efficient lookups by epoch_number
    create(index(:celo_aggregated_election_rewards, [:epoch_number]))
  end
end
