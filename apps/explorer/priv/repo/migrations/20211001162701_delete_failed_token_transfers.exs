defmodule Explorer.Repo.Migrations.DeleteFailedTokenTransfers do
  use Ecto.Migration

  def change do
    # WARNING: this is a painfully slow query as there is no index that would speed it up.
    # All failed token transfers have the internal failure error and gas = 0.
    # Records can be safely deleted as they don't affect balances.
    delete_failed_token_transfers = """
    DELETE FROM token_transfers WHERE transaction_hash IN (
      SELECT transaction_hash FROM internal_transactions WHERE call_type = 'call' AND error = 'internal failure' AND gas = 0
    ) AND log_index < 0;
    """

    execute(delete_failed_token_transfers)
  end
end
