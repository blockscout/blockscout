defmodule Explorer.Repo.Migrations.AddBlockRewardToPools do
  use Ecto.Migration

  def change do
    alter table(:staking_pools) do
      add(:block_reward_ratio, :decimal, precision: 5, scale: 2)
    end
  end
end
