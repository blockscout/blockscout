defmodule Explorer.Repo.Migrations.AddMissingColumnsToCeloEpochRewards do
  use Ecto.Migration

  def change do
    create table(:celo_epoch_rewards) do
      add(:block_hash, :bytea, null: false)
      add(:block_number, :integer, null: false)
      add(:epoch_number, :integer)
      add(:validator_target_epoch_rewards, :numeric, precision: 100)
      add(:voter_target_epoch_rewards, :numeric, precision: 100)
      add(:community_target_epoch_rewards, :numeric, precision: 100)
      add(:carbon_offsetting_target_epoch_rewards, :numeric, precision: 100)
      add(:target_total_supply, :numeric, precision: 100)
      add(:rewards_multiplier, :numeric, precision: 100)
      add(:rewards_multiplier_max, :numeric, precision: 100)
      add(:rewards_multiplier_under, :numeric, precision: 100)
      add(:rewards_multiplier_over, :numeric, precision: 100)
      add(:target_voting_yield, :numeric, precision: 100)
      add(:target_voting_yield_max, :numeric, precision: 100)
      add(:target_voting_yield_adjustment_factor, :numeric, precision: 100)
      add(:target_voting_fraction, :numeric, precision: 100)
      add(:voting_fraction, :numeric, precision: 100)
      add(:total_locked_gold, :numeric, precision: 100)
      add(:total_non_voting, :numeric, precision: 100)
      add(:total_votes, :numeric, precision: 100)
      add(:electable_validators_max, :integer)
      add(:reserve_gold_balance, :numeric, precision: 100)
      add(:gold_total_supply, :numeric, precision: 100)
      add(:stable_usd_total_supply, :numeric, precision: 100)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_epoch_rewards, [:block_hash], unique: true))
  end
end
