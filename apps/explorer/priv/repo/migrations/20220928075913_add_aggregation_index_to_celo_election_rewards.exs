defmodule Explorer.Repo.Migrations.AddAggregationIndexToCeloElectionRewards do
  use Ecto.Migration

  def change do
    create(index(:celo_election_rewards, [:block_number, :amount, :reward_type]))
  end
end
