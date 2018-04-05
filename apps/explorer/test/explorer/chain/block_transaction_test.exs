defmodule Explorer.Chain.BlockTransactionTest do
  use Explorer.DataCase

  alias Explorer.Chain.BlockTransaction

  describe "changeset/2" do
    test "with empty attributes" do
      changeset = BlockTransaction.changeset(%BlockTransaction{}, %{})
      refute(changeset.valid?)
    end

    test "with valid attributes" do
      attrs = %{block_id: 4, transaction_id: 3}
      changeset = BlockTransaction.changeset(%BlockTransaction{}, attrs)
      assert(changeset.valid?)
    end
  end
end
