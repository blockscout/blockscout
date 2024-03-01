defmodule Explorer.Repo.Arbitrum.Migrations.CreateArbitrumTables do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE arbitrum_messages_op_type AS ENUM ('to_l2', 'from_l2')",
      "DROP TYPE arbitrum_messages_op_type"
    )

    execute(
      "CREATE TYPE arbitrum_messages_status AS ENUM ('initiated', 'sent', 'confirmed', 'relayed')",
      "DROP TYPE arbitrum_messages_status"
    )

    execute(
      "CREATE TYPE l1_tx_status AS ENUM ('unfinalized', 'finalized')",
      "DROP TYPE l1_tx_status"
    )

    create table(:arbitrum_crosslevel_messages, primary_key: false) do
      add(:direction, :arbitrum_messages_op_type, null: false, primary_key: true)
      add(:message_id, :integer, null: false, primary_key: true)
      add(:originator_address, :bytea, null: true)
      add(:originating_tx_hash, :bytea, null: true)
      add(:origination_timestamp, :"timestamp without time zone", null: true)
      add(:originating_tx_blocknum, :bigint, null: true)
      add(:completion_tx_hash, :bytea, null: true)
      add(:status, :arbitrum_messages_status, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create table(:arbitrum_lifecycle_l1_transactions, primary_key: false) do
      add(:id, :integer, null: false, primary_key: true)
      add(:hash, :bytea, null: false)
      add(:block, :integer, null: false)
      add(:timestamp, :"timestamp without time zone", null: false)
      add(:status, :l1_tx_status, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:arbitrum_lifecycle_l1_transactions, :hash))

    create table(:arbitrum_l1_executions, primary_key: false) do
      add(:message_id, :integer, null: false, primary_key: true)

      add(
        :execution_id,
        references(:arbitrum_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: false
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create table(:arbitrum_l1_batches, primary_key: false) do
      add(:number, :integer, null: false, primary_key: true)
      add(:tx_count, :integer, null: false)
      add(:start_block, :integer, null: false)
      add(:end_block, :integer, null: false)
      add(:before_acc, :bytea, null: false)
      add(:after_acc, :bytea, null: false)

      add(
        :commit_id,
        references(:arbitrum_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: false
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create table(:arbitrum_batch_l2_blocks, primary_key: false) do
      add(
        :batch_number,
        references(:arbitrum_l1_batches,
          column: :number,
          on_delete: :delete_all,
          on_update: :update_all,
          type: :integer
        ),
        null: false
      )

      add(
        :confirm_id,
        references(:arbitrum_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: true
      )

      add(:hash, :bytea, null: false, primary_key: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:arbitrum_batch_l2_blocks, :batch_number))

    create table(:arbitrum_batch_l2_transactions, primary_key: false) do
      add(
        :batch_number,
        references(:arbitrum_l1_batches,
          column: :number,
          on_delete: :delete_all,
          on_update: :update_all,
          type: :integer
        ),
        null: false
      )

      add(
        :block_hash,
        references(:arbitrum_batch_l2_blocks,
          column: :hash,
          on_delete: :delete_all,
          on_update: :update_all,
          type: :bytea
        ),
        null: false
      )

      add(:hash, :bytea, null: false, primary_key: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:arbitrum_batch_l2_transactions, :batch_number))
  end
end
