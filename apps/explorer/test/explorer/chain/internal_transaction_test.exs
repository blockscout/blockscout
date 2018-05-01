defmodule Explorer.Chain.InternalTransactionTest do
  use Explorer.DataCase

  alias Explorer.Chain.InternalTransaction

  describe "changeset/2" do
    test "with valid attributes" do
      transaction = insert(:transaction)

      changeset =
        InternalTransaction.changeset(%InternalTransaction{}, %{
          call_type: "call",
          from_address_hash: "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b",
          gas: 100,
          gas_used: 100,
          index: 0,
          input: "pintos",
          output: "refried",
          to_address_hash: "0x6295ee1b4f6dd65047762f924ecd367c17eabf8f",
          trace_address: [0, 1],
          transaction_hash: transaction.hash,
          type: "call",
          value: 100
        })

      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = InternalTransaction.changeset(%InternalTransaction{}, %{falala: "falafel"})
      refute changeset.valid?
    end

    test "that a valid changeset is persistable" do
      transaction = insert(:transaction)

      changeset =
        InternalTransaction.changeset(%InternalTransaction{}, %{
          call_type: "call",
          gas: 100,
          gas_used: 100,
          index: 0,
          input: "thin-mints",
          output: "munchos",
          trace_address: [0, 1],
          transaction: transaction,
          type: "call",
          value: 100,
        })

      assert Repo.insert(changeset)
    end
  end
end
