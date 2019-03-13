defmodule Explorer.Repo.Migrations.ChangeTransactionsVColumnType do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      modify(:v, :numeric, precision: 100, null: false)
    end
  end
end
