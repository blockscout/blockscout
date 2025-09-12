defmodule Explorer.Repo.Migrations.CreateArchivalInternalTransactionsTable do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:archival_internal_transactions, primary_key: false) do
      add(:call_type, :string, null: true)
      add(:created_contract_code, :bytea, null: true)
      # null unless there is an error
      add(:error, :string, null: true)
      # no gas budget for suicide
      add(:gas, :numeric, precision: 100, null: true)
      # can be null when `error` is not `null`
      # no gas_used for suicide
      add(:gas_used, :numeric, precision: 100, null: true)
      add(:index, :integer, null: false, primary_key: true)
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

      add(:block_number, :integer)
      add(:transaction_index, :integer)

      add(:block_hash, references(:blocks, column: :hash, type: :bytea), null: false, primary_key: true)
      add(:block_index, :integer, null: false, primary_key: true)
    end
  end
end
