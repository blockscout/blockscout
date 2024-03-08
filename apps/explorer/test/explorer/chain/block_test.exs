defmodule Explorer.Chain.BlockTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.{Block, Wei}

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

  describe "block_reward_by_parts/1" do
    setup do
      {:ok, emission_reward: insert(:emission_reward)}
    end

    test "without uncles", %{emission_reward: %{reward: reward, block_range: range}} do
      block = build(:block, number: range.from, base_fee_per_gas: 5, uncles: [])

      tx1 = build(:transaction, gas_price: 1, gas_used: 1, block_number: block.number, block_hash: block.hash)
      tx2 = build(:transaction, gas_price: 1, gas_used: 2, block_number: block.number, block_hash: block.hash)

      tx3 =
        build(:transaction,
          gas_price: 1,
          gas_used: 3,
          block_number: block.number,
          block_hash: block.hash,
          max_priority_fee_per_gas: 1
        )

      expected_transaction_fees = %Wei{value: Decimal.new(6)}
      expected_burnt_fees = %Wei{value: Decimal.new(30)}
      expected_uncle_reward = %Wei{value: Decimal.new(0)}

      assert %{
               static_reward: ^reward,
               transaction_fees: ^expected_transaction_fees,
               burnt_fees: ^expected_burnt_fees,
               uncle_reward: ^expected_uncle_reward
             } = Block.block_reward_by_parts(block, [tx1, tx2, tx3])
    end

    test "with uncles", %{emission_reward: %{reward: reward, block_range: range}} do
      block =
        build(:block,
          number: range.from,
          uncles: ["0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d15273311"]
        )

      expected_uncle_reward = Wei.div(reward, 32)

      assert %{uncle_reward: ^expected_uncle_reward} = Block.block_reward_by_parts(block, [])
    end
  end

  describe "next_block_base_fee_per_gas" do
    test "with no blocks in the database returns nil" do
      assert Block.next_block_base_fee_per_gas() == nil
    end

    test "ignores non consensus blocks" do
      insert(:block, consensus: false, base_fee_per_gas: Wei.from(Decimal.new(1), :wei))
      assert Block.next_block_base_fee_per_gas() == nil
    end

    test "returns the next block base fee" do
      insert(:block,
        consensus: true,
        base_fee_per_gas: Wei.from(Decimal.new(1000), :wei),
        gas_limit: Decimal.new(30_000_000),
        gas_used: Decimal.new(15_000_000)
      )

      assert Block.next_block_base_fee_per_gas() == Decimal.new(1000)

      insert(:block,
        consensus: true,
        base_fee_per_gas: Wei.from(Decimal.new(1000), :wei),
        gas_limit: Decimal.new(30_000_000),
        gas_used: Decimal.new(3_000_000)
      )

      assert Block.next_block_base_fee_per_gas() == Decimal.new(900)

      insert(:block,
        consensus: true,
        base_fee_per_gas: Wei.from(Decimal.new(1000), :wei),
        gas_limit: Decimal.new(30_000_000),
        gas_used: Decimal.new(27_000_000)
      )

      assert Block.next_block_base_fee_per_gas() == Decimal.new(1100)
    end
  end
end
