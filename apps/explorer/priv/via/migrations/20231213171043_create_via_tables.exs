defmodule Explorer.Repo.Via.Migrations.CreateViaTables do
  use Ecto.Migration

  def change do
    create table(:via_lifecycle_l1_transactions, primary_key: false) do
      add(:id, :integer, null: false, primary_key: true)
      add(:hash, :bytea, null: false)
      add(:timestamp, :"timestamp without time zone", null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:via_lifecycle_l1_transactions, :hash))

    create table(:via_transaction_batches, primary_key: false) do
      add(:number, :integer, null: false, primary_key: true)
      add(:timestamp, :"timestamp without time zone", null: false)
      add(:l1_transaction_count, :integer, null: false)
      add(:l2_transaction_count, :integer, null: false)
      add(:root_hash, :bytea, null: false)
      add(:l1_gas_price, :numeric, precision: 100, null: false)
      add(:l2_fair_gas_price, :numeric, precision: 100, null: false)
      add(:start_block, :integer, null: false)
      add(:end_block, :integer, null: false)

      add(
        :commit_id,
        references(:via_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: true
      )

      add(
        :prove_id,
        references(:via_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: true
      )

      add(
        :execute_id,
        references(:via_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: true
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create table(:via_batch_l2_transactions, primary_key: false) do
      add(
        :batch_number,
        references(:via_transaction_batches,
          column: :number,
          on_delete: :delete_all,
          on_update: :update_all,
          type: :integer
        ),
        null: false
      )

      add(:transaction_hash, :bytea, null: false, primary_key: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:via_batch_l2_transactions, :batch_number))

    create table(:via_batch_l2_blocks, primary_key: false) do
      add(
        :batch_number,
        references(:via_transaction_batches,
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

    create(index(:via_batch_l2_blocks, :batch_number))
  end
end
