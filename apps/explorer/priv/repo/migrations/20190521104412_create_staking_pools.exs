defmodule Explorer.Repo.Migrations.CreateStakingPools do
  use Ecto.Migration

  def change do
    create table(:staking_pools) do
      add(:is_active, :boolean, default: false, null: false)
      add(:is_deleted, :boolean, default: false, null: false)
      add(:delegators_count, :integer)
      add(:staked_amount, :numeric, precision: 100)
      add(:self_staked_amount, :numeric, precision: 100)
      add(:is_validator, :boolean, default: false, null: false)
      add(:was_validator_count, :integer)
      add(:is_banned, :boolean, default: false, null: false)
      add(:was_banned_count, :integer)
      add(:banned_until, :bigint)
      add(:likelihood, :decimal, precision: 5, scale: 2)
      add(:staked_ratio, :decimal, precision: 5, scale: 2)
      add(:staking_address_hash, :bytea)
      add(:mining_address_hash, :bytea)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:staking_pools, [:staking_address_hash], unique: true))
    create(index(:staking_pools, [:mining_address_hash]))
  end
end
