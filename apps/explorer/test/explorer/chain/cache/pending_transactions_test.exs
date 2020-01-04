defmodule Explorer.Chain.Cache.PendingTransactionsTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.PendingTransactions

  describe "update_pending/1" do
    test "adds a new pending transaction" do
      transaction = insert(:transaction, block_hash: nil, error: nil)

      PendingTransactions.update([transaction])

      assert [%{hash: pending_transaction_hash}] = PendingTransactions.all()

      assert transaction.hash == pending_transaction_hash
    end
  end
end
