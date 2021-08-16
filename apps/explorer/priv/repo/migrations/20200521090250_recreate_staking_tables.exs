defmodule Explorer.Repo.Migrations.RecreateStakingTables do
  use Ecto.Migration

  def change do
    # rename table(:staking_pools), :staked_amount, to: :total_staked_amount
    # rename table(:staking_pools), :staked_ratio, to: :stakes_ratio
    # alter table(:staking_pools) do
    #   add(:validator_reward_percent, :decimal, precision: 5, scale: 2)
    #   add(:is_unremovable, :boolean, default: false, null: false)
    #   add(:are_delegators_banned, :boolean, default: false)
    #   add(:ban_reason, :string)
    #   add(:banned_delegators_until, :bigint)
    #   add(:snapshotted_total_staked_amount, :numeric, precision: 100)
    #   add(:snapshotted_self_staked_amount, :numeric, precision: 100)
    #   add(:validator_reward_ratio, :decimal, precision: 5, scale: 2)
    #   add(:snapshotted_validator_reward_ratio, :decimal, precision: 5, scale: 2)
    # end

    # rename table(:staking_pools_delegators), :delegator_address_hash, to: :address_hash
    # rename table(:staking_pools_delegators), :pool_address_hash, to: :staking_address_hash
    # alter table(:staking_pools_delegators) do
    #   add(:is_active, :boolean, default: true)
    #   add(:is_deleted, :boolean, default: false)
    #   add(:reward_ratio, :decimal, precision: 5, scale: 2)
    #   add(:snapshotted_stake_amount, :numeric, precision: 100)
    #   add(:snapshotted_reward_ratio, :decimal, precision: 5, scale: 2)
    # end

    # create(
    #   index(:staking_pools_delegators, [:staking_address_hash, :snapshotted_stake_amount, :is_active],
    #     unique: false,
    #     name: :snapshotted_stake_amount_index
    #   )
    # )

    drop_if_exists(table(:staking_pools))
    drop_if_exists(table(:staking_pools_delegators))

    create table(:staking_pools) do
      add(:are_delegators_banned, :boolean, default: false)
      add(:banned_delegators_until, :bigint)
      add(:banned_until, :bigint)
      add(:ban_reason, :string)
      add(:delegators_count, :integer)
      add(:is_active, :boolean, default: false, null: false)
      add(:is_banned, :boolean, default: false, null: false)
      add(:is_deleted, :boolean, default: false, null: false)
      add(:is_unremovable, :boolean, default: false, null: false)
      add(:is_validator, :boolean, default: false, null: false)
      add(:likelihood, :decimal, precision: 5, scale: 2)
      add(:mining_address_hash, :bytea)
      add(:self_staked_amount, :numeric, precision: 100)
      add(:snapshotted_self_staked_amount, :numeric, precision: 100)
      add(:snapshotted_total_staked_amount, :numeric, precision: 100)
      add(:snapshotted_validator_reward_ratio, :decimal, precision: 5, scale: 2)
      add(:stakes_ratio, :decimal, precision: 5, scale: 2)
      add(:staking_address_hash, :bytea)
      add(:total_staked_amount, :numeric, precision: 100)
      add(:validator_reward_percent, :decimal, precision: 5, scale: 2)
      add(:validator_reward_ratio, :decimal, precision: 5, scale: 2)
      add(:was_banned_count, :integer)
      add(:was_validator_count, :integer)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:staking_pools, [:staking_address_hash], unique: true))
    create(index(:staking_pools, [:mining_address_hash]))

    create table(:staking_pools_delegators) do
      add(:address_hash, :bytea)
      add(:is_active, :boolean, default: true)
      add(:is_deleted, :boolean, default: false)
      add(:max_ordered_withdraw_allowed, :numeric, precision: 100)
      add(:max_withdraw_allowed, :numeric, precision: 100)
      add(:ordered_withdraw, :numeric, precision: 100)
      add(:ordered_withdraw_epoch, :integer)
      add(:reward_ratio, :decimal, precision: 5, scale: 2)
      add(:snapshotted_reward_ratio, :decimal, precision: 5, scale: 2)
      add(:snapshotted_stake_amount, :numeric, precision: 100)
      add(:stake_amount, :numeric, precision: 100)
      add(:staking_address_hash, :bytea)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(
      index(:staking_pools_delegators, [:address_hash, :staking_address_hash],
        unique: true,
        name: :pools_delegator_index
      )
    )

    create(
      index(:staking_pools_delegators, [:staking_address_hash, :snapshotted_stake_amount, :is_active],
        unique: false,
        name: :snapshotted_stake_amount_index
      )
    )
  end
end
