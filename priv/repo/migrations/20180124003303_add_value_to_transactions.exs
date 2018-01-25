defmodule Explorer.Repo.Migrations.AddValueToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :value, :numeric, precision: 100, null: false
    end
  end
end
