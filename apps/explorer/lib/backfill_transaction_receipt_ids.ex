defmodule BackfillTransactionReceiptIds do
  @moduledoc "Backfills transactions with receipt_id values"
  alias Explorer.Repo

  def run do
    query = """
      UPDATE transactions SET (receipt_id) = (
        SELECT id FROM receipts WHERE receipts.transaction_id = transactions.id
      );
    """

    {:ok, _result} = Repo.query(query, [])
  end
end
