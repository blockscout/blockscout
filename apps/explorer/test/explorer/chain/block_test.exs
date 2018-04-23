defmodule Explorer.Chain.BlockTest do
  use Explorer.DataCase

  alias Explorer.Chain.Block

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
      %Block{hash: hash} = insert(:block)

      {:error, changeset} = %Block{} |> Block.changeset(params_for(:block, hash: hash)) |> Repo.insert()

      refute changeset.valid?
      assert changeset.errors == [hash: {"has already been taken", []}]
    end

    test "rejects duplicate blocks with mixed case" do
      insert(:block, hash: "0xef95f2f1ed3ca60b048b4bf67cde2195961e0bba6f70bcbea9a2c4e133e34b46")

      {:error, changeset} =
        %Block{}
        |> Block.changeset(
          params_for(:block, hash: "0xeF95f2f1ed3ca60b048b4bf67cde2195961e0bba6f70bcbea9a2c4e133e34b46")
        )
        |> Repo.insert()

      refute changeset.valid?
      assert changeset.errors == [hash: {"has already been taken", []}]
    end
  end
end
