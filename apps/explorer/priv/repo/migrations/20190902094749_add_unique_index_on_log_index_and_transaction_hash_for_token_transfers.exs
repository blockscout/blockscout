defmodule Explorer.Repo.Migrations.AddUniqueIndexOnLogIndexAndTransactionHashForTokenTransfers do
  use Ecto.Migration

  alias Ecto.Adapters.SQL
  alias Explorer.Repo

  def change do
    drop_if_exists(index(:token_transfers, [:transaction_hash, :log_index]))

    remove_duplicate_token_transfers()

    create_if_not_exists(unique_index(:token_transfers, [:transaction_hash, :log_index]))
  end

  defp remove_duplicate_token_transfers do
    query = """
      DELETE FROM token_transfers
        WHERE ctid NOT IN (
          SELECT MIN(ctid)
          FROM token_transfers
          GROUP BY transaction_hash, log_index, block_number)
    """

    SQL.query!(Repo, query, [], timeout: :infinity)
  end
end
