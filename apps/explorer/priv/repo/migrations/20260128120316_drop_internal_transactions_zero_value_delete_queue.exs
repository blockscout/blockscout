defmodule Explorer.Repo.Migrations.DropInternalTransactionsZeroValueDeleteQueue do
  use Ecto.Migration

  def change do
    drop(table(:internal_transactions_zero_value_delete_queue))
  end
end
