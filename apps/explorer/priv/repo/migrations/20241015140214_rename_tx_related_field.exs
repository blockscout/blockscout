defmodule Explorer.Repo.Migrations.RenameTxRelatedField do
  use Ecto.Migration

  def change do
    rename(table(:transactions), :has_error_in_internal_txs, to: :has_error_in_internal_transactions)
  end
end
