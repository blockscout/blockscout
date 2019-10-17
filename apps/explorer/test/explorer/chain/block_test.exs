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

      assert {:error, %Changeset{valid?: false, errors: [hash: {"has already been taken", _}]}} =
               %Block{}
               |> Block.changeset(params_for(:block, hash: hash, miner_hash: miner_hash))
               |> Repo.insert()
    end

    test "rejects duplicate blocks with mixed case" do
      %Block{miner_hash: miner_hash} =
        insert(:block, hash: "0xef95f2f1ed3ca60b048b4bf67cde2195961e0bba6f70bcbea9a2c4e133e34b46")

      assert {:error, %Changeset{valid?: false, errors: [hash: {"has already been taken", _}]}} =
               %Block{}
               |> Block.changeset(
                 params_for(
                   :block,
                   hash: "0xeF95f2f1ed3ca60b048b4bf67cde2195961e0bba6f70bcbea9a2c4e133e34b46",
                   miner_hash: miner_hash
                 )
               )
               |> Repo.insert()
    end
  end

  describe "blocks_without_reward_query/1" do
    test "finds only blocks without rewards" do
      rewarded_block = insert(:block)
      insert(:reward, address_hash: insert(:address).hash, block_hash: rewarded_block.hash)
      unrewarded_block = insert(:block)

      results =
        Block.blocks_without_reward_query()
        |> Repo.all()
        |> Enum.map(& &1.hash)

      refute Enum.member?(results, rewarded_block.hash)
      assert Enum.member?(results, unrewarded_block.hash)
    end
  end
end
