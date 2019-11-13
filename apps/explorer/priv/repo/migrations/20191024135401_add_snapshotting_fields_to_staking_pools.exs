defmodule Explorer.Repo.Migrations.AddSnapshottingFieldsToStakingPools do
  use Ecto.Migration

  def change do
    alter table(:staking_pools) do
      add(:snapshotted_total_staked_amount, :numeric, precision: 100)
      add(:snapshotted_self_staked_amount, :numeric, precision: 100)
      add(:validator_reward_ratio, :decimal, precision: 5, scale: 2)
      add(:snapshotted_validator_reward_ratio, :decimal, precision: 5, scale: 2)
    end
  end
end
