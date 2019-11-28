defmodule Explorer.Repo.Migrations.CreateIndexesForBlockNumberInTokenTransfersAndTransactions do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:token_transfers, [:block_number]))
  end
end
