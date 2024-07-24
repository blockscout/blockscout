defmodule Explorer.Repo.ZkSync.Migrations.CreateZkSyncTables do
  use Ecto.Migration

  def change do
    create table(:zksync_lifecycle_l1_transactions, primary_key: false) do
      add(:id, :integer, null: false, primary_key: true)
      add(:hash, :bytea, null: false)
      add(:timestamp, :"timestamp without time zone", null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:zksync_lifecycle_l1_transactions, :hash))

    create table(:zksync_transaction_batches, primary_key: false) do
      add(:number, :integer, null: false, primary_key: true)
      add(:timestamp, :"timestamp without time zone", null: false)
      add(:l1_tx_count, :integer, null: false)
      add(:l2_tx_count, :integer, null: false)
      add(:root_hash, :bytea, null: false)
      add(:l1_gas_price, :numeric, precision: 100, null: false)
      add(:l2_fair_gas_price, :numeric, precision: 100, null: false)
      add(:start_block, :integer, null: false)
      add(:end_block, :integer, null: false)

      add(
        :commit_id,
        references(:zksync_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: true
      )

      add(
        :prove_id,
        references(:zksync_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: true
      )

      add(
        :execute_id,
        references(:zksync_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: true
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create table(:zksync_batch_l2_transactions, primary_key: false) do
      add(
        :batch_number,
        references(:zksync_transaction_batches,
          column: :number,
          on_delete: :delete_all,
          on_update: :update_all,
          type: :integer
        ),
        null: false
      )

      add(:hash, :bytea, null: false, primary_key: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:zksync_batch_l2_transactions, :batch_number))

    create table(:zksync_batch_l2_blocks, primary_key: false) do
      add(
        :batch_number,
        references(:zksync_transaction_batches,
          column: :number,
          on_delete: :delete_all,
          on_update: :update_all,
          type: :integer
        ),
        null: false
      )

      add(:hash, :bytea, null: false, primary_key: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:zksync_batch_l2_blocks, :batch_number))
  end
end
