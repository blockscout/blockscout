defmodule Explorer.Repo.Migrations.AddHotContractsDaily do
  use Ecto.Migration

  def change do
    create table(:hot_smart_contracts_daily, primary_key: false) do
      add(:date, :date, null: false, primary_key: true)
      add(:contract_address_hash, :bytea, null: false, primary_key: true)
      add(:transactions_count, :integer, null: false)
      add(:total_gas_used, :numeric, precision: 100, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(
      index(:hot_smart_contracts_daily, ["date DESC", "total_gas_used DESC"], name: :idx_hot_smart_contracts_date_gas)
    )

    create(
      index(:hot_smart_contracts_daily, ["date DESC", "transactions_count DESC"],
        name: :idx_hot_smart_contracts_date_transactions_count
      )
    )
  end
end
