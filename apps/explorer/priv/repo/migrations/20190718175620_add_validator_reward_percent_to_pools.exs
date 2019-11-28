defmodule Explorer.Repo.Migrations.AddValidatorRewardPercentToPools do
  use Ecto.Migration

  def change do
    alter table(:staking_pools) do
      add(:validator_reward_percent, :decimal, precision: 5, scale: 2)
    end
  end
end
