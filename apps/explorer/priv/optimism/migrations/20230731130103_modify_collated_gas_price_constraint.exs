defmodule Explorer.Repo.Optimism.Migrations.ModifyCollatedGasPriceConstraint do
  use Ecto.Migration

  def change do
    execute("ALTER TABLE transactions DROP CONSTRAINT collated_gas_price")

    create(
      constraint(
        :transactions,
        :collated_gas_price,
        check: "block_hash IS NULL OR gas_price IS NOT NULL OR max_fee_per_gas IS NOT NULL"
      )
    )
  end
end
