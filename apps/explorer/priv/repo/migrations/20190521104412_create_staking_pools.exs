defmodule Explorer.Repo.Migrations.CreateStakingPools do
  use Ecto.Migration

  def change do
    create table(:staking_pools) do
      add(:is_active, :boolean, default: false, null: false)
      add(:delegators_count, :integer)
      add(:staked_amount, :numeric, precision: 100)
      add(:self_staked_amount, :numeric, precision: 100)
      add(:is_validator, :boolean, default: false, null: false)
      add(:was_validator_count, :integer)
      add(:is_banned, :boolean, default: false, null: false)
      add(:was_banned_count, :integer)
      add(:banned_until, :bigint)
      add(:likelihood, :decimal)
      add(:staked_ratio, :decimal)
      add(:min_delegators_stake, :numeric, precision: 100)
      add(:min_candidate_stake, :numeric, precision: 100)
      add(:staking_address_hash, references(:addresses, on_delete: :nothing, column: :hash, type: :bytea))
      add(:mining_address_hash, references(:addresses, on_delete: :nothing, column: :hash, type: :bytea))

      timestamps()
    end

    create(index(:staking_pools, [:staking_address_hash]))
    create(index(:staking_pools, [:mining_address_hash]))
  end
end
