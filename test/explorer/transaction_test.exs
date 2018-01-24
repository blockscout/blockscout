defmodule Explorer.TransactionTest do
  use Explorer.DataCase

  alias Explorer.Transaction

  describe "changeset/2" do
    test "with valid attributes" do
      block = insert(:block)
      changeset = Transaction.changeset(%Transaction{}, %{hash: "0x0", block_id: block.id})
      assert changeset.valid?
    end

    test "with a block that does not exist in the database" do
      {:error, changeset} = Transaction.changeset(%Transaction{}, %{hash: "0x0", block_id: 0}) |> Repo.insert
      refute changeset.valid?
      assert [block_id: {"does not exist", []}] = changeset.errors
    end

    test "with invalid attributes" do
      changeset = Transaction.changeset(%Transaction{}, %{racecar: "yellow ham"})
      refute changeset.valid?
    end
  end
end
