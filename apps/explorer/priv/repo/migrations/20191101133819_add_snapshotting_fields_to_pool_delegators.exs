defmodule Explorer.Repo.Migrations.AddSnapshottingFieldsToPoolDelegators do
  use Ecto.Migration

  def change do
    alter table(:staking_pools_delegators) do
      add(:snapshotted_stake_amount, :numeric, precision: 100)
      add(:snapshotted_reward_ratio, :decimal, precision: 5, scale: 2)
    end
  end
end
