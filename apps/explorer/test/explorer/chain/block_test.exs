defmodule Explorer.Chain.BlockTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.Block

  describe "changeset/2" do
    test "with valid attributes" do
      assert %Changeset{valid?: true} =
               :block
               |> build(miner_hash: build(:address).hash)
               |> Block.changeset(%{})
    end

    test "with invalid attributes" do
      changeset = %Block{} |> Block.changeset(%{racecar: "yellow ham"})
      refute(changeset.valid?)
    end

    test "with duplicate information" do
      %Block{hash: hash, miner_hash: miner_hash} = insert(:block)

      assert {:error, %Changeset{errors: errors, valid?: false}} =
               %Block{}
               |> Block.changeset(params_for(:block, hash: hash, miner_hash: miner_hash))
               |> Repo.insert()

      assert errors == [hash: {"has already been taken", []}]
    end

    test "rejects duplicate blocks with mixed case" do
      %Block{miner_hash: miner_hash} =
        insert(:block, hash: "0xef95f2f1ed3ca60b048b4bf67cde2195961e0bba6f70bcbea9a2c4e133e34b46")

      {:error, changeset} =
        %Block{}
        |> Block.changeset(
          params_for(
            :block,
            hash: "0xeF95f2f1ed3ca60b048b4bf67cde2195961e0bba6f70bcbea9a2c4e133e34b46",
            miner_hash: miner_hash
          )
        )
        |> Repo.insert()

      refute changeset.valid?
      assert changeset.errors == [hash: {"has already been taken", []}]
    end
  end
end
