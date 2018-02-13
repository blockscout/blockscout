defmodule Explorer.TransactionReceiptTest do
  use Explorer.DataCase

  alias Explorer.TransactionReceipt

  describe "changeset/2" do
    test "accepts valid attributes" do
      transaction = insert(:transaction)
      params = params_for(:transaction_receipt, transaction: transaction)
      changeset = TransactionReceipt.changeset(%TransactionReceipt{}, params)
      assert changeset.valid?
    end

    test "rejects missing attributes" do
      transaction = insert(:transaction)
      params = params_for(:transaction_receipt, transaction: transaction, cumulative_gas_used: nil)
      changeset = TransactionReceipt.changeset(%TransactionReceipt{}, params)
      refute changeset.valid?
    end
  end
end
