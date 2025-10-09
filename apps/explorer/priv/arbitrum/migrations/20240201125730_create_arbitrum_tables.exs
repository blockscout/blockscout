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
      add(:originating_transaction_hash, :bytea, null: true)
      add(:origination_timestamp, :"timestamp without time zone", null: true)
      add(:originating_transaction_block_number, :bigint, null: true)
      add(:completion_transaction_hash, :bytea, null: true)
      add(:status, :arbitrum_messages_status, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:arbitrum_crosslevel_messages, [:direction, :originating_transaction_block_number, :status]))
    create(index(:arbitrum_crosslevel_messages, [:direction, :completion_transaction_hash]))

    create table(:arbitrum_lifecycle_l1_transactions, primary_key: false) do
      add(:id, :integer, null: false, primary_key: true)
      add(:hash, :bytea, null: false)
      add(:block_number, :integer, null: false)
      add(:timestamp, :"timestamp without time zone", null: false)
      add(:status, :l1_tx_status, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:arbitrum_lifecycle_l1_transactions, :hash))
    create(index(:arbitrum_lifecycle_l1_transactions, [:block_number, :status]))

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
      add(:transactions_count, :integer, null: false)
      add(:start_block, :integer, null: false)
      add(:end_block, :integer, null: false)
      add(:before_acc, :bytea, null: false)
      add(:after_acc, :bytea, null: false)

      add(
        :commitment_id,
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
        :confirmation_id,
        references(:arbitrum_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: true
      )

      # Although it is possible to recover the block number from the block hash,
      # it is more efficient to store it directly
      # There could be no DB inconsistencies with `blocks` table caused be re-orgs
      # because the blocks will appear in the table `arbitrum_batch_l2_blocks`
      # only when they are included in the batch.
      add(:block_number, :integer, null: false, primary_key: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:arbitrum_batch_l2_blocks, :batch_number))
    create(index(:arbitrum_batch_l2_blocks, :confirmation_id))

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

      add(:tx_hash, :bytea, null: false, primary_key: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:arbitrum_batch_l2_transactions, :batch_number))
  end
end
