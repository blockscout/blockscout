defmodule Explorer.Chain.Cache.PendingTransactionsTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.PendingTransactions

  describe "update_pending/1" do
    test "adds a new pending transaction" do
      transaction = insert(:transaction, block_hash: nil, error: nil)

      PendingTransactions.update([transaction])

      transaction_hash = transaction.hash

      assert [%{hash: transaction_hash}] = PendingTransactions.all()
    end
  end
end
