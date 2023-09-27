defmodule Explorer.Repo.Suave.Migrations.AddSuaveTransactionFields do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:execution_node_hash, :bytea, null: true)
      add(:wrapped_type, :integer, null: true)
      add(:wrapped_nonce, :integer, null: true)
      add(:wrapped_to_address_hash, :bytea, null: true)
      add(:wrapped_gas, :numeric, precision: 100, null: true)
      add(:wrapped_gas_price, :numeric, precision: 100, null: true)
      add(:wrapped_max_priority_fee_per_gas, :numeric, precision: 100, null: true)
      add(:wrapped_max_fee_per_gas, :numeric, precision: 100, null: true)
      add(:wrapped_value, :numeric, precision: 100, null: true)
      add(:wrapped_input, :bytea, null: true)
      add(:wrapped_v, :numeric, precision: 100, null: true)
      add(:wrapped_r, :numeric, precision: 100, null: true)
      add(:wrapped_s, :numeric, precision: 100, null: true)
      add(:wrapped_hash, :bytea, null: true)
    end

    create(index(:transactions, :execution_node_hash))
  end
end
