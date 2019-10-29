defmodule Explorer.Repo.Migrations.AddBlockHashToAllEntities do
  use Ecto.Migration

  def change do
    alter table(:internal_transactions) do
      add(:block_hash, :bytea)
    end

    create(index(:internal_transactions, [:block_hash]))
  end
end
