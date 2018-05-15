defmodule Explorer.Chain.ReceiptTest do
  use Explorer.DataCase

  alias Explorer.Chain.Receipt

  describe "changeset/2" do
    test "accepts valid attributes" do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      params = params_for(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)

      changeset = Receipt.changeset(%Receipt{}, params)

      assert changeset.valid?
    end

    test "rejects missing attributes" do
      transaction = insert(:transaction)
      params = params_for(:receipt, transaction: transaction, cumulative_gas_used: nil)

      changeset = Receipt.changeset(%Receipt{}, params)

      refute changeset.valid?
    end
  end
end
