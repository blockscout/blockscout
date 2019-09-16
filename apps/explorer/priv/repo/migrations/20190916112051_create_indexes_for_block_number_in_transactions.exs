defmodule Explorer.Repo.Migrations.CreateIndexesForBlockNumberInTransactions do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:transactions, [:block_number]))
  end
end
