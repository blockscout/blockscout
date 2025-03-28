defmodule Explorer.Repo.Optimism.Migrations.OPInteropMessages do
  use Ecto.Migration

  def change do
    drop_if_exists(table(:op_interop_messages))

    create table(:op_interop_messages, primary_key: false) do
      add(:sender, :bytea, null: true, default: nil)
      add(:target, :bytea, null: true, default: nil)
      add(:nonce, :bigint, null: false, primary_key: true)
      add(:init_chain_id, :integer, null: false, primary_key: true)
      add(:init_transaction_hash, :bytea, null: true, default: nil)
      add(:block_number, :bigint, null: true, default: nil)
      add(:timestamp, :"timestamp without time zone", null: true, default: nil)
      add(:relay_chain_id, :integer, null: false)
      add(:relay_transaction_hash, :bytea, null: true, default: nil)
      add(:payload, :bytea, null: true, default: nil)
      add(:failed, :boolean, null: true, default: nil)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:op_interop_messages, [:init_transaction_hash, :timestamp]))
    create(index(:op_interop_messages, [:init_transaction_hash, :relay_chain_id]))
    create(index(:op_interop_messages, [:relay_transaction_hash, :init_chain_id]))
    create(index(:op_interop_messages, [:block_number, :failed]))
  end
end
