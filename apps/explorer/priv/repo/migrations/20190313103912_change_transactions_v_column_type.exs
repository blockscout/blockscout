defmodule Explorer.Repo.Migrations.ChangeTransactionsVColumnType do
  use Ecto.Migration

  def up do
    alter table(:transactions) do
      modify(:v, :numeric, precision: 100, null: false)
    end
  end

  def down do
    alter table(:transactions) do
      modify(:v, :integer, null: false)
    end
  end
end
