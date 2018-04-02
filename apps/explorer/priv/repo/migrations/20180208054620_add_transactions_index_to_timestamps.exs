defmodule Explorer.Repo.Migrations.AddTransactionsIndexToTimestamps do
  use Ecto.Migration

  def change do
    create index(:transactions, :inserted_at)
    create index(:transactions, :updated_at)
  end
end
