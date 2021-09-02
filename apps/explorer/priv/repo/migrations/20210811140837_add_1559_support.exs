defmodule Explorer.Repo.Migrations.Add1559Support do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:max_priority_fee_per_gas, :numeric, precision: 100, null: true)
      add(:max_fee_per_gas, :numeric, precision: 100, null: true)
      add(:type, :integer, null: true)
    end

    alter table(:blocks) do
      add(:base_fee_per_gas, :numeric, precision: 100, null: true)
    end
  end
end
