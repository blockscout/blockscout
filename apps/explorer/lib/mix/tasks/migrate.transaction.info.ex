defmodule Mix.Tasks.Migrate.Transaction.Info do
  use Mix.Task

  alias Explorer.Repo
  alias Ecto.Adapters.SQL

  @shortdoc "Migrates transaction info to internal transaction"

  @moduledoc """
  This task is reponsible to populate the `transaction_index` and
  `block_number` at the `internal_transactions` table, using the
  `transactions` info.
  """

  def run(_args) do
    {:ok, _} = Application.ensure_all_started(:explorer)

    SQL.query(
      Repo,
      """
        UPDATE internal_transactions
        SET
          block_number = transactions.block_number,
          transaction_index = transactions.index
        FROM transactions
        WHERE internal_transactions.transaction_hash = transactions.hash;
      """,
      [],
      timeout: :infinity
    )
  end
end
