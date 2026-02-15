defmodule Explorer.Repo.Migrations.CreateFheOperations do
  use Ecto.Migration

  def change do
    create table(:fhe_operations, primary_key: false) do
      add(:transaction_hash, references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false,
        primary_key: true
      )

      add(:log_index, :integer, null: false, primary_key: true)
      add(:block_hash, references(:blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      add(:block_number, :bigint, null: false)

      # Operation details
      add(:operation, :string, size: 50, null: false)
      add(:operation_type, :string, size: 20, null: false)
      add(:fhe_type, :string, size: 10, null: false)
      add(:is_scalar, :boolean, null: false)

      # HCU metrics
      add(:hcu_cost, :integer, null: false)
      add(:hcu_depth, :integer, null: false)

      # Addresses and handles
      add(:caller, :bytea)
      add(:result_handle, :bytea, null: false)
      add(:input_handles, :map)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    # Indexes for efficient queries
    create(index(:fhe_operations, ["block_number DESC"]))
    create(index(:fhe_operations, [:caller], where: "caller IS NOT NULL"))
    create(index(:fhe_operations, [:operation_type]))
    create(index(:fhe_operations, [:fhe_type]))
    create(index(:fhe_operations, [:operation]))
  end
end
