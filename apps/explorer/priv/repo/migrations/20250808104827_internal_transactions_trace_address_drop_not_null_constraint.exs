defmodule Explorer.Repo.Migrations.InternalTransactionsTraceAddressDropNotNullConstraint do
  use Ecto.Migration

  def up do
    alter table(:internal_transactions) do
      modify(:trace_address, {:array, :integer}, null: true)
    end
  end

  def down do
    alter table(:internal_transactions) do
      modify(:trace_address, {:array, :integer}, null: false)
    end
  end
end
