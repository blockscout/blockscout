defmodule Explorer.Repo.Migrations.RemoveInternalTransactionsIndexedAtFromTransactionsTable do
  use Ecto.Migration

  def change do
  	alter table(:transactions) do
      remove(:internal_transactions_indexed_at)
    end
  end
end
