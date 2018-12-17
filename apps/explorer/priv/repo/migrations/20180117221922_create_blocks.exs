defmodule Explorer.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks, primary_key: false) do
      add(:consensus, :boolean, null: false)
      add(:difficulty, :numeric, precision: 50)
      add(:gas_limit, :numeric, precision: 100, null: false)
      add(:gas_used, :numeric, precision: 100, null: false)
      add(:hash, :bytea, null: false, primary_key: true)
      add(:miner_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:nonce, :bytea, null: false)
      add(:number, :bigint, null: false)

      # not a foreign key to allow skipped blocks
      add(:parent_hash, :bytea, null: false)

      add(:size, :integer, null: false)
      add(:timestamp, :utc_datetime_usec, null: false)
      add(:total_difficulty, :numeric, precision: 50)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:blocks, [:timestamp]))
    create(index(:blocks, [:parent_hash], unique: true, where: ~s(consensus), name: :one_consensus_child_per_parent))
    create(index(:blocks, [:number], unique: true, where: ~s(consensus), name: :one_consensus_block_at_height))
  end
end
