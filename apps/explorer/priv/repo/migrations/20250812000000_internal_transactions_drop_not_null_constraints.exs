defmodule Explorer.Repo.Migrations.InternalTransactionsDropNotNullConstraints do
  use Ecto.Migration

  def up do
    alter table(:internal_transactions) do
      modify(:trace_address, {:array, :integer}, null: true)
      modify(:value, :numeric, precision: 100, null: true)
    end
  end

  def down do
    alter table(:internal_transactions) do
      modify(:trace_address, {:array, :integer}, null: false)
      modify(:value, :numeric, precision: 100, null: false)
    end
  end
end
