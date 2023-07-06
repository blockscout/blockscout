defmodule Explorer.Repo.Migrations.CreateExternalTransactions do
  use Ecto.Migration

  def change do
    create table(:external_transactions, primary_key: false) do
      # `null` when a pending transaction
      add(:cumulative_gas_used, :numeric, precision: 100, null: true)

      # `null` before internal transactions are fetched or if no error in those internal transactions
      add(:error, :string, null: true)

      add(:gas, :numeric, precision: 100, null: false)
      add(:gas_price, :numeric, precision: 100, null: false)

      # `null` when a pending transaction
      add(:gas_used, :numeric, precision: 100, null: true)

      add(:hash, :bytea, null: false, primary_key: true)

      # `null` when a pending transaction
      add(:index, :integer, null: true)

      add(:input, :bytea, null: false)

      add(:nonce, :integer, null: false)
      add(:r, :numeric, precision: 100, null: false)
      add(:s, :numeric, precision: 100, null: false)

      # `null` when a pending transaction
      add(:status, :integer, null: true)

      add(:v, :numeric, precision: 100, null: false)
      add(:value, :numeric, precision: 100, null: false)

      timestamps(null: false, type: :utc_datetime_usec)

      # `null` when a pending transaction
      add(:block_hash, references(:blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: true)
#      add(:block_hash, :bytea, null: true)

      # `null` when a pending transaction
      # denormalized from `blocks.number` to improve `Explorer.Chain.recent_collated_transactions/0` performance
      add(:block_number, :integer, null: true)

#      add(:from_address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      add(:from_address_hash, :bytea, null: false)
      # `null` when it is a contract creation transaction
#      add(:to_address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: true)
      add(:to_address_hash, :bytea, null: true)
#      add(:created_contract_address_hash, references(:addresses, column: :hash, type: :bytea), null: true)
      add(:created_contract_address_hash, :bytea, null: true)
      add(:max_priority_fee_per_gas, :numeric, precision: 100, null: true)
      add(:max_fee_per_gas, :numeric, precision: 100, null: true)
      add(:type, :integer, null: true)
      add(:created_contract_code_indexed_at, :utc_datetime_usec, null: true)
      add(:earliest_processing_start, :utc_datetime_usec)
      add(:revert_reason, :text)
      add(:old_block_hash, :bytea, null: true)
    end

    create(index(:external_transactions, [:created_contract_code_indexed_at]))

#    create(
#      constraint(
#        :external_transactions,
#        :collated_block_number,
#        check: "block_hash IS NULL OR block_number IS NOT NULL"
#      )
#    )
#
#    create(
#      constraint(
#        :external_transactions,
#        :collated_cumalative_gas_used,
#        check: "block_hash IS NULL OR cumulative_gas_used IS NOT NULL"
#      )
#    )
#
#    create(
#      constraint(
#        :external_transactions,
#        :collated_gas_used,
#        check: "block_hash IS NULL OR gas_used IS NOT NULL"
#      )
#    )
#
#    create(
#      constraint(
#        :external_transactions,
#        :collated_index,
#        check: "block_hash IS NULL OR index IS NOT NULL"
#      )
#    )
#
#    create(
#      constraint(
#        :external_transactions,
#        :pending_block_number,
#        check: "block_hash IS NOT NULL OR block_number IS NULL"
#      )
#    )
#
#    create(
#      constraint(
#        :external_transactions,
#        :pending_cumalative_gas_used,
#        check: "block_hash IS NOT NULL OR cumulative_gas_used IS NULL"
#      )
#    )
#
#    create(
#      constraint(
#        :external_transactions,
#        :pending_gas_used,
#        check: "block_hash IS NOT NULL OR gas_used IS NULL"
#      )
#    )
#
#    create(
#      constraint(
#        :external_transactions,
#        :pending_index,
#        check: "block_hash IS NOT NULL OR index IS NULL"
#      )
#    )

    create(index(:external_transactions, :block_hash))

    create(index(:external_transactions, :inserted_at))
    create(index(:external_transactions, :updated_at))

    create(index(:external_transactions, :status))

    create(
      index(
        :external_transactions,
        ["block_number DESC NULLS FIRST", "index DESC NULLS FIRST"],
        name: "external_transactions_recent_collated_index"
      )
    )

    create(
      index(
        :external_transactions,
        [:from_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "external_transactions_from_address_hash_recent_collated_index"
      )
    )

    create(
      index(
        :external_transactions,
        [:to_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "external_transactions_to_address_hash_recent_collated_index"
      )
    )

    create(
      index(
        :external_transactions,
        [:created_contract_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "external_transactions_created_contract_address_hash_recent_collated_index"
      )
    )

    create(unique_index(:external_transactions, [:block_hash, :index]))
  end
end
