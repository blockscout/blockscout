defmodule Explorer.Repo.Signet.Migrations.CreateSignetTables do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE signet_fill_chain_type AS ENUM ('rollup', 'host')",
      "DROP TYPE signet_fill_chain_type"
    )

    create table(:signet_orders, primary_key: false) do
      # Primary key: outputs_witness_hash uniquely identifies an order
      add(:outputs_witness_hash, :bytea, null: false, primary_key: true)
      add(:deadline, :bigint, null: false)
      add(:block_number, :bigint, null: false)
      add(:transaction_hash, :bytea, null: false)
      add(:log_index, :integer, null: false)
      # JSON-encoded input/output arrays for flexibility
      add(:inputs_json, :text, null: false)
      add(:outputs_json, :text, null: false)
      # Sweep event data (nullable - only present if Sweep was emitted)
      add(:sweep_recipient, :bytea, null: true)
      add(:sweep_token, :bytea, null: true)
      add(:sweep_amount, :numeric, precision: 100, null: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    # Index for querying orders by block for reorg handling
    create(index(:signet_orders, [:block_number]))
    # Index for querying orders by transaction
    create(index(:signet_orders, [:transaction_hash]))
    # Index for finding unfilled orders by deadline
    create(index(:signet_orders, [:deadline]))

    create table(:signet_fills, primary_key: false) do
      # Composite primary key: witness_hash + chain_type
      # An order can be filled on both rollup and host chains
      add(:outputs_witness_hash, :bytea, null: false, primary_key: true)
      add(:chain_type, :signet_fill_chain_type, null: false, primary_key: true)
      add(:block_number, :bigint, null: false)
      add(:transaction_hash, :bytea, null: false)
      add(:log_index, :integer, null: false)
      add(:outputs_json, :text, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    # Index for querying fills by block for reorg handling
    create(index(:signet_fills, [:chain_type, :block_number]))
    # Index for querying fills by transaction
    create(index(:signet_fills, [:transaction_hash]))
    # Index for correlating fills back to orders
    create(index(:signet_fills, [:outputs_witness_hash]))
  end
end
