defmodule Explorer.Repo.Migrations.CreateInternalTransactions do
  use Ecto.Migration

  def change do
    create table(:internal_transactions) do
      add(:call_type, :string, null: true)
      add(:created_contract_code, :bytea, null: true)
      # null unless there is an error
      add(:error, :string, null: true)
      # no gas budget for suicide
      add(:gas, :numeric, precision: 100, null: true)
      # can be null when `error` is not `null`
      # no gas_used for suicide
      add(:gas_used, :numeric, precision: 100, null: true)
      add(:index, :integer, null: false)
      add(:init, :bytea)
      add(:input, :bytea)
      # can be null when `error` is not `null`
      add(:output, :bytea)
      add(:trace_address, {:array, :integer}, null: false)
      add(:type, :string, null: false)
      add(:value, :numeric, precision: 100, null: false)

      timestamps(null: false, type: :utc_datetime_usec)

      # Nullability controlled by create_has_created constraint below
      add(:created_contract_address_hash, references(:addresses, column: :hash, type: :bytea), null: true)
      add(:from_address_hash, references(:addresses, column: :hash, type: :bytea))
      add(:to_address_hash, references(:addresses, column: :hash, type: :bytea))

      add(
        :transaction_hash,
        references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )
    end

    create(
      constraint(
        :internal_transactions,
        :call_has_error_or_result,
        check: """
        type != 'call' OR
        (gas IS NOT NULL AND
         ((error IS NULL AND gas_used IS NOT NULL and output IS NOT NULL) OR
          (error IS NOT NULL AND gas_used IS NULL and output is NULL)))
        """
      )
    )

    create(
      constraint(
        :internal_transactions,
        :create_has_error_or_result,
        check: """
        type != 'create' OR
        (gas IS NOT NULL AND
         ((error IS NULL AND created_contract_address_hash IS NOT NULL AND created_contract_code IS NOT NULL AND gas_used IS NOT NULL) OR
          (error IS NOT NULL AND created_contract_address_hash IS NULL AND created_contract_code IS NULL AND gas_used IS NULL)))
        """
      )
    )

    create(
      constraint(
        :internal_transactions,
        :suicide_has_from_and_to_address_hashes,
        check: """
        type != 'suicide' OR
        (from_address_hash IS NOT NULL AND gas IS NULL AND to_address_hash IS NOT NULL)
        """
      )
    )

    create(index(:internal_transactions, :created_contract_address_hash))
    create(index(:internal_transactions, :from_address_hash))
    create(index(:internal_transactions, :to_address_hash))
    create(index(:internal_transactions, :transaction_hash))

    create(unique_index(:internal_transactions, [:transaction_hash, :index]))
  end
end
