defmodule Explorer.Repo.Migrations.ResetReserveBolster do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE celo_epoch_rewards
    SET reserve_bolster = 0
    """)
  end

  def down do
  end
end
