defmodule Explorer.Repo.Migrations.AddBlockRewardToPoolDelegators do
  use Ecto.Migration

  def change do
    alter table(:staking_pools_delegators) do
      add(:reward_ratio, :decimal, precision: 5, scale: 2)
    end
  end
end
