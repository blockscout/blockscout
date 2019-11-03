defmodule Explorer.Repo.Migrations.CreateInternalTransactionsIndexBlockHashBlockIndex do
  use Ecto.Migration

  def change do
	create(unique_index(:internal_transactions, [:block_hash, :block_index]))
  end
end
