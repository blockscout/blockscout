defmodule Explorer.Repo.Migrations.RemoveInternalTransactionsIndexedAtFromBlocksTable do
  use Ecto.Migration

  def change do

  	alter table(:blocks) do
      remove(:internal_transactions_indexed_at)
    end

  end
end
