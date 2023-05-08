defmodule Explorer.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
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

      # `null` when `internal_transactions` has never been fetched
      add(:internal_transactions_indexed_at, :utc_datetime_usec, null: true)

      add(:nonce, :integer, null: false)
      add(:r, :numeric, precision: 100, null: false)
      add(:s, :numeric, precision: 100, null: false)

      # `null` when a pending transaction
      add(:status, :integer, null: true)

      add(:v, :integer, null: false)
      add(:value, :numeric, precision: 100, null: false)

      timestamps(null: false, type: :utc_datetime_usec)

      # `null` when a pending transaction
      add(:block_hash, references(:blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: true)

      # `null` when a pending transaction
      # denormalized from `blocks.number` to improve `Explorer.Chain.recent_collated_transactions/0` performance
      add(:block_number, :integer, null: true)

      add(:from_address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      # `null` when it is a contract creation transaction
      add(:to_address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: true)
      add(:created_contract_address_hash, references(:addresses, column: :hash, type: :bytea), null: true)
    end

    create(
      constraint(
        :transactions,
        :collated_block_number,
        check: "block_hash IS NULL OR block_number IS NOT NULL"
      )
    )

    create(
      constraint(
        :transactions,
        :collated_cumulative_gas_used,
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
        :status,
        # 0 - NULL
        # 1 - NOT NULL
        #
        # | block_hash | internal_transactions_indexed_at | status | OK | description
        # |------------|----------------------------------|--------|----|------------
        # | 0          | 0                                | 0      | 1  | pending
        # | 0          | 0                                | 1      | 0  | pending with status
        # | 0          | 1                                | 0      | 0  | pending with internal transactions
        # | 0          | 1                                | 1      | 0  | pending with internal transactions and status
        # | 1          | 0                                | 0      | 1  | pre-byzantium collated transaction without internal transactions
        # | 1          | 0                                | 1      | 1  | post-byzantium collated transaction without internal transactions
        # | 1          | 1                                | 0      | 0  | pre-byzantium collated transaction with internal transaction without status
        # | 1          | 1                                | 1      | 1  | pre- or post-byzantium collated transaction with internal transactions and status
        #
        # [Karnaugh map](https://en.wikipedia.org/wiki/Karnaugh_map)
        # b \ is | 00 | 01 | 11 | 10 |
        # -------|----|----|----|----|
        #      0 | 1  | 0  | 0  | 0  |
        #      1 | 1  | 1  | 1  | 0  |
        #
        # Simplification: ¬i·¬s + b·¬i + b·s
        check: """
        (internal_transactions_indexed_at IS NULL AND status IS NULL) OR
        (block_hash IS NOT NULL AND internal_transactions_indexed_at IS NULL) OR
        (block_hash IS NOT NULL AND status IS NOT NULL)
        """
      )
    )

    create(
      constraint(
        :transactions,
        :error,
        # | status | internal_transactions_indexed_at | error    | OK         | description
        # |--------|----------------------------------|----------|------------|------------
        # | NULL   | NULL                             | NULL     | TRUE       | pending or pre-byzantium collated
        # | NULL   | NULL                             | NOT NULL | FALSE      | error cannot be known before internal transactions are indexed
        # | NULL   | NOT NULL                         | NULL     | DON'T CARE | handled by `status` check
        # | NULL   | NOT NULL                         | NOT NULL | FALSE      | error cannot be set unless status is known to be error (`0`)
        # | 0      | NULL                             | NULL     | TRUE       | post-byzantium before internal transactions indexed
        # | 0      | NULL                             | NOT NULL | FALSE      | error cannot be set unless internal transactions are indexed
        # | 0      | NOT NULL                         | NULL     | FALSE      | error MUST be set when status is error
        # | 0      | NOT NULL                         | NOT NULL | TRUE       | error is set when status is error
        # | 1      | NULL                             | NULL     | TRUE       | post-byzantium before internal transactions indexed
        # | 1      | NULL                             | NOT NULL | FALSE      | error cannot be set when status is ok
        # | 1      | NOT NULL                         | NULL     | TRUE       | error is not set when status is ok
        # | 1      | NOT NULL                         | NOT NULL | FALSE      | error cannot be set when status is ok
        #
        # Karnaugh map
        # s \ ie | NULL, NULL | NULL, NOT NULL | NOT NULL, NOT NULL | NOT NULL, NULL |
        # -------|------------|----------------|--------------------|----------------|
        # NULL   | TRUE       | FALSE          | FALSE              | DON'T CARE     |
        # 0      | TRUE       | FALSE          | TRUE               | FALSE          |
        # 1      | TRUE       | FALSE          | FALSE              | TRUE           |
        #
        check: """
        (internal_transactions_indexed_at IS NULL AND error IS NULL) OR
        (status = 0 AND internal_transactions_indexed_at IS NOT NULL AND error IS NOT NULL) OR
        (status != 0 AND internal_transactions_indexed_at IS NOT NULL AND error IS NULL)
        """
      )
    )

    create(
      constraint(
        :transactions,
        :pending_block_number,
        check: "block_hash IS NOT NULL OR block_number IS NULL"
      )
    )

    create(
      constraint(
        :transactions,
        :pending_cumulative_gas_used,
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

    create(index(:transactions, :block_hash))

    create(index(:transactions, :inserted_at))
    create(index(:transactions, :updated_at))

    create(index(:transactions, :status))

    create(
      index(
        :transactions,
        ["block_number DESC NULLS FIRST", "index DESC NULLS FIRST"],
        name: "transactions_recent_collated_index"
      )
    )

    create(
      index(
        :transactions,
        [:from_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_from_address_hash_recent_collated_index"
      )
    )

    create(
      index(
        :transactions,
        [:to_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_to_address_hash_recent_collated_index"
      )
    )

    create(
      index(
        :transactions,
        [:created_contract_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_created_contract_address_hash_recent_collated_index"
      )
    )

    create(unique_index(:transactions, [:block_hash, :index]))
  end
end
