defmodule Explorer.TransactionTest do
  use Explorer.DataCase

  alias Explorer.Transaction

  describe "changeset/2" do
    test "with valid attributes" do
      block = insert(:block)
      changeset = Transaction.changeset(%Transaction{}, %{hash: "0x0", block_id: block.id, value: 1, gas: 21000, gas_price: 10000, input: "0x5c8eff12", nonce: "31337", public_key: "0xb39af9c", r: "0x9", s: "0x10", standard_v: "0x11", transaction_index: "0x12", v: "0x13"})
      assert changeset.valid?
    end

    test "with a block that does not exist in the database" do
      {:error, changeset} = Transaction.changeset(%Transaction{}, %{hash: "0x0", block_id: 0, value: 1, gas: 21000, gas_price: 10000, input: "0x5c8eff12", nonce: "31337", public_key: "0xb39af9c", r: "0x9", s: "0x10", standard_v: "0x11", transaction_index: "0x12", v: "0x13"}) |> Repo.insert
      refute changeset.valid?
      assert [block_id: {"does not exist", []}] = changeset.errors
    end

    test "with invalid attributes" do
      changeset = Transaction.changeset(%Transaction{}, %{racecar: "yellow ham"})
      refute changeset.valid?
    end
  end
end
