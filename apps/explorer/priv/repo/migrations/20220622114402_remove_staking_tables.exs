defmodule Explorer.Repo.Migrations.RemoveStakingTables do
  use Ecto.Migration

  def change do
    execute("""
    DROP TABLE staking_pools_delegators CASCADE;
    """)

    execute("""
    DROP TABLE staking_pools CASCADE;
    """)
  end
end
