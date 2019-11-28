defmodule Explorer.Repo.Migrations.AddIndexForSnapshottedStakeAmount do
  use Ecto.Migration

  def change do
  	create(
      index(:staking_pools_delegators, [:staking_address_hash, :snapshotted_stake_amount, :is_active],
        unique: false,
        name: :snapshotted_stake_amount_index
      )
    )
  end
end
