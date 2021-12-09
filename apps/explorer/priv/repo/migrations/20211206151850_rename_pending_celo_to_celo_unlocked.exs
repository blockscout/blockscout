defmodule Explorer.Repo.Migrations.RenamePendingCeloToCeloUnlocked do
  use Ecto.Migration

  def change do
    rename(table(:pending_celo), to: table(:celo_unlocked))
  end
end
