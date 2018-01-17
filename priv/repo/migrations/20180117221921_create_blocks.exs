defmodule Explorer.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :number, :bigint, null: false
      add :hash, :string, null: false
      add :parent_hash, :string, null: false
      add :nonce, :string, null: false
      add :miner, :string, null: false
      add :difficulty, :numeric, precision: 50
      add :total_difficulty, :numeric, precision: 50
      add :size, :integer, null: false
      add :gas_limit, :integer, null: false
      add :gas_used, :integer, null: false
      add :timestamp, :utc_datetime, null: false
      timestamps null: false
    end

    create unique_index(:blocks, ["(lower(hash))"], name: :blocks_hash_index)
    create index(:blocks, [:number])
  end
end
