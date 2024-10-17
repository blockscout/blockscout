defmodule Explorer.Repo.Migrations.AllowNilTransactionGasPrice do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      modify(:gas_price, :numeric, precision: 100, null: true)
    end

    create(
      constraint(
        :transactions,
        :collated_gas_price,
        check: "block_hash IS NULL OR gas_price IS NOT NULL"
      )
    )
  end
end
