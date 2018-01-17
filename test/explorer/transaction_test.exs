defmodule Explorer.TransactionTest do
  use Explorer.DataCase

  alias Explorer.Transaction

  describe "changeset/2" do
    test "with valid attributes" do
      block = insert(:block)
      changeset = Transaction.changeset(%Transaction{}, %{block_id: block.id, hash: "0x0"})
      assert(changeset.valid?)
    end

    test "with an invalid block" do
      {:error, changeset} = Transaction.changeset(%Transaction{}, %{block_id: 0, hash: "0x0"}) |> Repo.insert
      assert changeset.errors == [block_id: {"does not exist", []}]
      refute changeset.valid?
    end

    test "with invalid attributes" do
      changeset = Transaction.changeset(%Transaction{}, %{racecar: "yellow ham"})
      refute(changeset.valid?)
    end
  end
end
