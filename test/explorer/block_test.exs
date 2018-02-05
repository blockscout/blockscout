defmodule Explorer.BlockTest do
  use Explorer.DataCase

  alias Explorer.Block
  import Ecto.Query, only: [order_by: 2]

  describe "changeset/2" do
    test "with valid attributes" do
      changeset = build(:block) |> Block.changeset(%{})
      assert(changeset.valid?)
    end

    test "with invalid attributes" do
      changeset = %Block{} |> Block.changeset(%{racecar: "yellow ham"})
      refute(changeset.valid?)
    end

    test "with duplicate information" do
      insert(:block, hash: "0x0")
      {:error, changeset} = %Block{} |> Block.changeset(params_for(:block, hash: "0x0")) |> Repo.insert
      refute changeset.valid?
      assert changeset.errors == [hash: {"has already been taken", []}]
    end

    test "rejects duplicate blocks with mixed case" do
      insert(:block, hash: "0xa")
      {:error, changeset} = %Block{} |> Block.changeset(params_for(:block, hash: "0xA")) |> Repo.insert
      refute changeset.valid?
      assert changeset.errors == [hash: {"has already been taken", []}]
    end
  end

  describe "null/0" do
    test "returns a block with a number of 0" do
      assert Block.null.number === -1
    end
  end

  describe "latest/1" do
    test "returns the blocks sorted by number" do
      insert(:block, number: 1)
      insert(:block, number: 5)
      assert Block |> Block.latest |> Repo.all == Block |> order_by(desc: :number) |> Repo.all
    end
  end
end
