defmodule Explorer.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :difficulty, :numeric, precision: 50
      add :gas_limit, :integer, null: false
      add :gas_used, :integer, null: false
      add :hash, :string, null: false
      add :miner, :string, null: false
      add :nonce, :string, null: false
      add :number, :bigint, null: false
      add :parent_hash, :string, null: false
      add :size, :integer, null: false
      add :timestamp, :utc_datetime, null: false
      add :total_difficulty, :numeric, precision: 50

      timestamps null: false
    end

    create index(:blocks, [:timestamp])
    create unique_index(:blocks, [:hash])
    create unique_index(:blocks, [:number])
  end
end
