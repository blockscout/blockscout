defmodule Explorer.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      # `null` when a pending transaction
      add(:cumulative_gas_used, :numeric, precision: 100, null: true)

      add(:gas, :numeric, precision: 100, null: false)
      add(:gas_price, :numeric, precision: 100, null: false)

      # `null` when a pending transaction
      add(:gas_used, :numeric, precision: 100, null: true)

      add(:hash, :bytea, null: false, primary_key: true)

      # `null` when a pending transaction
      add(:index, :integer, null: true)

      add(:input, :bytea, null: false)
      add(:nonce, :integer, null: false)
      add(:public_key, :bytea, null: false)
      add(:r, :numeric, precision: 100, null: false)
      add(:s, :numeric, precision: 100, null: false)
      add(:standard_v, :smallint, null: false)

      # `null` when a pending transaction
      add(:status, :integer, null: true)

      add(:v, :integer, null: false)
      add(:value, :numeric, precision: 100, null: false)

      timestamps(null: false)

      # `null` when a pending transaction
      add(:block_hash, references(:blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: true)

      add(:from_address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      # `null` when it is a contract creation transaction
      add(:to_address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: true)
    end

    create(
      constraint(
        :transactions,
        :collated_cumalative_gas_used,
        check: "block_hash IS NULL OR cumulative_gas_used IS NOT NULL"
      )
    )

    create(
      constraint(
        :transactions,
        :collated_gas_used,
        check: "block_hash IS NULL OR gas_used IS NOT NULL"
      )
    )

    create(
      constraint(
        :transactions,
        :collated_index,
        check: "block_hash IS NULL OR index IS NOT NULL"
      )
    )

    create(
      constraint(
        :transactions,
        :collated_status,
        check: "block_hash IS NULL OR status IS NOT NULL"
      )
    )

    create(
      constraint(
        :transactions,
        :pending_cumalative_gas_used,
        check: "block_hash IS NOT NULL OR cumulative_gas_used IS NULL"
      )
    )

    create(
      constraint(
        :transactions,
        :pending_gas_used,
        check: "block_hash IS NOT NULL OR gas_used IS NULL"
      )
    )

    create(
      constraint(
        :transactions,
        :pending_index,
        check: "block_hash IS NOT NULL OR index IS NULL"
      )
    )

    create(
      constraint(
        :transactions,
        :pending_status,
        check: "block_hash IS NOT NULL OR status IS NULL"
      )
    )

    create(constraint(:transactions, :standard_v, check: "0 <= standard_v AND standard_v <= 3"))

    create(index(:transactions, :block_hash))
    create(index(:transactions, :from_address_hash))
    create(index(:transactions, :to_address_hash))

    create(index(:transactions, :inserted_at))
    create(index(:transactions, :updated_at))

    create(index(:transactions, :status))
    create(index(:transactions, ["index DESC NULLS FIRST"], name: "transactions_index_index"))

    create(unique_index(:transactions, [:block_hash, :index]))
  end
end
