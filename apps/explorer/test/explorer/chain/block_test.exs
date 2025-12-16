defmodule Explorer.Chain.BlockTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.{Address, Block, PendingBlockOperation, Wei}
  alias Explorer.PagingOptions

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

  describe "block_combined_rewards/1" do
    test "sums the block_rewards values" do
      block = insert(:block)

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :validator,
        reward: Decimal.new(1_000_000_000_000_000_000)
      )

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :emission_funds,
        reward: Decimal.new(1_000_000_000_000_000_000)
      )

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :uncle,
        reward: Decimal.new(1_000_000_000_000_000_000)
      )

      block = Repo.preload(block, :rewards)

      {:ok, expected_value} = Wei.cast(3_000_000_000_000_000_000)

      assert Block.block_combined_rewards(block) == expected_value
    end
  end

  describe "fetch_min_block_number/0" do
    test "fetches min block numbers" do
      for index <- 5..9 do
        insert(:block, number: index)
        Process.sleep(200)
      end

      assert 5 = Block.fetch_min_block_number()
    end

    test "fetches min when there are no blocks" do
      assert 0 = Block.fetch_min_block_number()
    end
  end

  describe "fetch_max_block_number/0" do
    test "fetches max block numbers" do
      for index <- 5..9 do
        insert(:block, number: index)
      end

      assert 9 = Block.fetch_max_block_number()
    end

    test "fetches max when there are no blocks" do
      assert 0 = Block.fetch_max_block_number()
    end
  end

  describe "get_blocks_validated_by_address/2" do
    test "returns nothing when there are no blocks" do
      %Address{hash: address_hash} = insert(:address)

      assert [] = Block.get_blocks_validated_by_address(address_hash)
    end

    test "returns the blocks validated by a specified address" do
      %Address{hash: address_hash} = address = insert(:address)
      another_address = insert(:address)

      block = insert(:block, miner: address, miner_hash: address.hash)
      insert(:block, miner: another_address, miner_hash: another_address.hash)

      results =
        address_hash
        |> Block.get_blocks_validated_by_address()
        |> Enum.map(& &1.hash)

      assert results == [block.hash]
    end

    test "with blocks can be paginated" do
      %Address{hash: address_hash} = address = insert(:address)

      first_page_block = insert(:block, miner: address, miner_hash: address.hash, number: 0)
      second_page_block = insert(:block, miner: address, miner_hash: address.hash, number: 2)

      assert [first_page_block.number] ==
               [paging_options: %PagingOptions{key: {1}, page_size: 1}]
               |> Block.get_blocks_validated_by_address(address_hash)
               |> Enum.map(& &1.number)
               |> Enum.reverse()

      assert [second_page_block.number] ==
               [paging_options: %PagingOptions{key: {3}, page_size: 1}]
               |> Block.get_blocks_validated_by_address(address_hash)
               |> Enum.map(& &1.number)
               |> Enum.reverse()
    end
  end

  describe "stream_blocks_without_rewards/2" do
    test "includes consensus blocks" do
      %Block{hash: consensus_hash} = insert(:block, consensus: true)

      assert {:ok, [%Block{hash: ^consensus_hash}]} = Block.stream_blocks_without_rewards([], &[&1 | &2])
    end

    test "does not include consensus block that has a reward" do
      %Block{hash: consensus_hash, miner_hash: miner_hash} = insert(:block, consensus: true)
      insert(:reward, address_hash: miner_hash, block_hash: consensus_hash)

      assert {:ok, []} = Block.stream_blocks_without_rewards([], &[&1 | &2])
    end

    # https://github.com/poanetwork/blockscout/issues/1310 regression test
    test "does not include non-consensus blocks" do
      insert(:block, consensus: false)

      assert {:ok, []} = Block.stream_blocks_without_rewards([], &[&1 | &2])
    end
  end

  describe "block_hash_by_number/1" do
    test "without blocks returns empty map" do
      assert Block.block_hash_by_number([]) == %{}
    end

    test "with consensus block returns mapping" do
      block = insert(:block)

      assert Block.block_hash_by_number([block.number]) == %{block.number => block.hash}
    end

    test "with non-consensus block does not return mapping" do
      block = insert(:block, consensus: false)

      assert Block.block_hash_by_number([block.number]) == %{}
    end
  end

  describe "stream_unfetched_uncles/2" do
    test "does not return uncle hashes where t:Explorer.Chain.Block.SecondDegreeRelation.t/0 uncle_fetched_at is not nil" do
      %Block.SecondDegreeRelation{nephew: %Block{}, nephew_hash: nephew_hash, index: index, uncle_hash: uncle_hash} =
        insert(:block_second_degree_relation)

      assert {:ok, [%{nephew_hash: ^nephew_hash, index: ^index}]} =
               Block.stream_unfetched_uncles([], &[&1 | &2])

      query = from(bsdr in Block.SecondDegreeRelation, where: bsdr.uncle_hash == ^uncle_hash)

      assert {1, _} = Repo.update_all(query, set: [uncle_fetched_at: DateTime.utc_now()])

      assert {:ok, []} = Block.stream_unfetched_uncles([], &[&1 | &2])
    end
  end

  describe "remove_nonconsensus_blocks_from_pending_ops/0" do
    test "removes pending ops for nonconsensus blocks" do
      block = insert(:block)
      insert(:pending_block_operation, block: block, block_number: block.number)

      nonconsensus_block = insert(:block, consensus: false)
      insert(:pending_block_operation, block: nonconsensus_block, block_number: nonconsensus_block.number)

      config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(config, :block_traceable?, true))

      on_exit(fn -> Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, config) end)

      :ok = Block.remove_nonconsensus_blocks_from_pending_ops()

      assert Repo.get(PendingBlockOperation, block.hash)
      assert is_nil(Repo.get(PendingBlockOperation, nonconsensus_block.hash))
    end

    test "removes pending ops for nonconsensus blocks by block hashes" do
      block = insert(:block)
      insert(:pending_block_operation, block: block, block_number: block.number)

      nonconsensus_block = insert(:block, consensus: false)
      insert(:pending_block_operation, block: nonconsensus_block, block_number: nonconsensus_block.number)

      nonconsensus_block1 = insert(:block, consensus: false)
      insert(:pending_block_operation, block: nonconsensus_block1, block_number: nonconsensus_block1.number)

      config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(config, :block_traceable?, true))

      on_exit(fn -> Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, config) end)

      :ok = Block.remove_nonconsensus_blocks_from_pending_ops([nonconsensus_block1.hash])

      assert Repo.get(PendingBlockOperation, block.hash)
      assert Repo.get(PendingBlockOperation, nonconsensus_block.hash)
      assert is_nil(Repo.get(PendingBlockOperation, nonconsensus_block1.hash))
    end
  end

  describe "gas_payment_by_block_hash/1" do
    setup do
      number = 1

      block = insert(:block, number: number, consensus: true)

      %{consensus_block: block, number: number}
    end

    test "without consensus block hash has key with 0 value", %{consensus_block: consensus_block, number: number} do
      non_consensus_block = insert(:block, number: number, consensus: false)

      :transaction
      |> insert(gas_price: 1, block_consensus: false)
      |> with_block(consensus_block, gas_used: 1)

      :transaction
      |> insert(gas_price: 1, block_consensus: false)
      |> with_block(consensus_block, gas_used: 2)

      assert Block.gas_payment_by_block_hash([non_consensus_block.hash]) == %{
               non_consensus_block.hash => %Wei{value: Decimal.new(0)}
             }
    end

    test "with consensus block hash without transactions has key with 0 value", %{
      consensus_block: %Block{hash: consensus_block_hash}
    } do
      assert Block.gas_payment_by_block_hash([consensus_block_hash]) == %{
               consensus_block_hash => %Wei{value: Decimal.new(0)}
             }
    end

    test "with consensus block hash with transactions has key with value", %{
      consensus_block: %Block{hash: consensus_block_hash} = consensus_block
    } do
      :transaction
      |> insert(gas_price: 1)
      |> with_block(consensus_block, gas_used: 2)

      :transaction
      |> insert(gas_price: 3)
      |> with_block(consensus_block, gas_used: 4)

      assert Block.gas_payment_by_block_hash([consensus_block_hash]) == %{
               consensus_block_hash => %Wei{value: Decimal.new(14)}
             }
    end
  end
end
