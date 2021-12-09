defmodule Explorer.Repo.Migrations.UpdateCeloUnlocked do
  use Ecto.Migration

  def change do
    drop(index(:celo_withdrawal, [:account_address, :index], unique: true))
    rename(table("celo_unlocked"), :timestamp, to: :available)

    alter table(:celo_unlocked) do
      remove(:index)
    end
  end
end
