defmodule Explorer.Repo.Migrations.AddIndexOnTransactionHashLogIndexBlockNumberForTokenTransfres do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:token_transfers, [:transaction_hash, :log_index, :block_number]))
  end
end
