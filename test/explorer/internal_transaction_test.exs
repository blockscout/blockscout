defmodule Explorer.InternalTransactionTest do
  use Explorer.DataCase

  alias Explorer.InternalTransaction

  describe "changeset/2" do
    test "with valid attributes" do
      transaction = insert(:transaction)
      changeset = InternalTransaction.changeset(%InternalTransaction{}, %{transaction_id: transaction.id, index: 0, call_type: "call", trace_address: [0, 1], value: 100, gas: 100, gas_used: 100, input: "pintos", output: "refried", to_address_id: 1, from_address_id: 2})
      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = InternalTransaction.changeset(%InternalTransaction{}, %{falala: "falafel"})
      refute changeset.valid?
    end

    test "that a valid changeset is persistable" do
      transaction = insert(:transaction)
      changeset = InternalTransaction.changeset(%InternalTransaction{}, %{transaction: transaction, index: 0, call_type: "call", trace_address: [0, 1], value: 100, gas: 100, gas_used: 100, input: "thin-mints", output: "munchos"})
      assert Repo.insert(changeset)
    end
  end
end
