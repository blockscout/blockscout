defmodule Explorer.SkippedReceiptsTest do
  use Explorer.DataCase

  alias Explorer.SkippedReceipts

  describe "first/0 when there are no transactions" do
    test "returns no transactions" do
      assert SkippedReceipts.first() == []
    end
  end

  describe "first/0 when there are no skipped transactions" do
    test "returns no transactions" do
      transaction = insert(:transaction)
      insert(:transaction_receipt, transaction: transaction)
      assert SkippedReceipts.first() == []
    end
  end

  describe "first/0 when a transaction has been skipped" do
    test "returns the first skipped transaction hash" do
      insert(:transaction, %{hash: "0xBEE75"})
      assert SkippedReceipts.first() == ["0xBEE75"]
    end
  end

  describe "first/1 when there are no transactions" do
    test "returns no transactions" do
      assert SkippedReceipts.first(1) == []
    end
  end

  describe "first/1 when there are no skipped transactions" do
    test "returns no transactions" do
      transaction = insert(:transaction)
      insert(:transaction_receipt, transaction: transaction)
      assert SkippedReceipts.first(1) == []
    end
  end

  describe "first/1 when a transaction has been skipped" do
    test "returns the skipped transaction number" do
      insert(:transaction, %{hash: "0xBEE75"})
      assert SkippedReceipts.first(1) == ["0xBEE75"]
    end

    test "returns all the skipped transaction hashes in random order" do
      insert(:transaction, %{hash: "0xBEE75"})
      insert(:transaction, %{hash: "0xBE475"})
      transaction_hashes = SkippedReceipts.first(100)
      assert("0xBEE75" in transaction_hashes and "0xBE475" in transaction_hashes)
    end
  end
end
