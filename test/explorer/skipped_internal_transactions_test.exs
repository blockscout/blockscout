defmodule Explorer.SkippedInternalTransactionsTest do
  use Explorer.DataCase

  alias Explorer.SkippedInternalTransactions

  describe "first/0 when there are no transactions" do
    test "returns no transaction hashes" do
      assert SkippedInternalTransactions.first() == []
    end
  end

  describe "first/0 when there are transactions with internal transactions" do
    test "returns no transaction hashes" do
      transaction = insert(:transaction)
      insert(:internal_transaction, transaction: transaction)
      assert SkippedInternalTransactions.first() == []
    end
  end

  describe "first/0 when there are transactions with no internal transactions" do
    test "returns the transaction hash" do
      insert(:transaction, hash: "0xdeadbeef")
      assert SkippedInternalTransactions.first() == ["0xdeadbeef"]
    end
  end
end
