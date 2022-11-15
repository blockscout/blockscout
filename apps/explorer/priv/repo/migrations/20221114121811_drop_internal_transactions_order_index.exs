defmodule Explorer.Repo.Migrations.DropInternalTransactionsOrderIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:internal_transactions, ["block_number DESC, transaction_index DESC, index DESC"]))
  end
end
