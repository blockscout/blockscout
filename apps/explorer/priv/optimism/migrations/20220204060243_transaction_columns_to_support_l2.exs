defmodule Explorer.Repo.Migrations.TransactionColumnsToSupportL2 do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:l1_fee, :numeric, precision: 100, null: true)
      add(:l1_fee_scalar, :decimal, null: true)
      add(:l1_gas_price, :numeric, precision: 100, null: true)
      add(:l1_gas_used, :numeric, precision: 100, null: true)
      add(:l1_tx_origin, :bytea, null: true)
      add(:l1_block_number, :integer, null: true)
    end
  end
end
