defmodule Explorer.Repo.Migrations.AddPoolNameDescription do
  use Ecto.Migration

  def change do
    alter table(:staking_pools) do
      add(:name, :string, size: 256, null: true)
      add(:description, :string, size: 1024, null: true)
    end
  end
end
