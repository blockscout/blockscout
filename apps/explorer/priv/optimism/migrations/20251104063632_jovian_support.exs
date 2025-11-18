defmodule Explorer.Repo.Optimism.Migrations.JovianSupport do
  use Ecto.Migration

  def up do
    alter table(:op_eip1559_config_updates) do
      add(:min_base_fee, :bigint, null: true)
    end

    alter table(:transactions) do
      add(:da_footprint_gas_scalar, :decimal, null: true, default: nil)
    end
  end

  def down do
    alter table(:transactions) do
      remove(:da_footprint_gas_scalar)
    end

    alter table(:op_eip1559_config_updates) do
      remove(:min_base_fee)
    end
  end
end
