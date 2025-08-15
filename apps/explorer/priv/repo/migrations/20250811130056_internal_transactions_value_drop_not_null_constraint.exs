defmodule Explorer.Repo.Migrations.InternalTransactionsValueDropNotNullConstraint do
  use Ecto.Migration

  def up do
    alter table(:internal_transactions) do
      modify(:value, :numeric, precision: 100, null: true)
    end
  end

  def down do
    alter table(:internal_transactions) do
      modify(:value, :numeric, precision: 100, null: false)
    end
  end
end
