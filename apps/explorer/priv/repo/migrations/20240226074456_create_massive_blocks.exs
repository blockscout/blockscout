defmodule Explorer.Repo.Migrations.CreateMassiveBlocks do
  use Ecto.Migration

  def change do
    create table(:massive_blocks, primary_key: false) do
      add(:number, :bigint, primary_key: true)

      timestamps()
    end
  end
end
