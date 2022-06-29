defmodule Explorer.Repo.Migrations.RemoveStakingTables do
  use Ecto.Migration

  def change do
    drop_if_exists(table(:staking_pools_delegators))
    drop_if_exists(table(:staking_pools))
  end
end
