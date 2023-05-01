defmodule Explorer.Repo.Migrations.CreateZkevmTables do
  use Ecto.Migration

  def change do
    create table(:zkevm_lifecycle_l1_transactions, primary_key: false) do
      add(:id, :integer, null: false, primary_key: true)
      add(:hash, :bytea, null: false)
      add(:is_verify, :boolean, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:zkevm_lifecycle_l1_transactions, :hash))

    create table(:zkevm_transaction_batches, primary_key: false) do
      add(:number, :integer, null: false, primary_key: true)
      add(:timestamp, :"timestamp without time zone", null: false)
      add(:l2_transaction_hashes, {:array, :bytea}, null: false)
      add(:global_exit_root, :bytea, null: false)
      add(:acc_input_hash, :bytea, null: false)
      add(:state_root, :bytea, null: false)

      add(
        :sequence_id,
        references(:zkevm_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: true
      )

      add(
        :verify_id,
        references(:zkevm_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: true
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
