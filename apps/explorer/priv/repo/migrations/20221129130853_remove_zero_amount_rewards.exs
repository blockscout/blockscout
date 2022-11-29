defmodule Explorer.Repo.Local.Migrations.RemoveZeroAmountRewards do
  use Ecto.Migration

  def up do
    execute("""
      DELETE FROM celo_election_rewards WHERE amount = 0
    """)
  end

  def down do
  end
end
