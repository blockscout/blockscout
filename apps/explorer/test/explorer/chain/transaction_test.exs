defmodule Explorer.Chain.TransactionTest do
  use Explorer.DataCase

  import Mox

  alias Ecto.Changeset
  alias Explorer.Chain.{Address, InternalTransaction, Transaction}
  alias Explorer.{PagingOptions, TestHelper}

  doctest Transaction

  setup :set_mox_global

  setup :verify_on_exit!

  describe "changeset/2" do
    test "with valid attributes" do
      assert %Changeset{valid?: true} =
               Transaction.changeset(%Transaction{}, %{
                 from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                 hash: "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b",
                 value: 1,
                 gas: 21000,
                 gas_price: 10000,
                 input: "0x5c8eff12",
                 nonce: "31337",
                 r: 0x9,
                 s: 0x10,
                 transaction_index: "0x12",
                 v: 27
               })
    end

    test "with invalid attributes" do
      changeset = Transaction.changeset(%Transaction{}, %{racecar: "yellow ham"})
      refute changeset.valid?
    end

    test "it creates a new to address" do
      params = params_for(:transaction, from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      to_address_params = %{hash: "sk8orDi3"}
      changeset_params = Map.merge(params, %{to_address: to_address_params})

      assert %Changeset{valid?: true} = Transaction.changeset(%Transaction{}, changeset_params)
    end
  end

  describe "transactions_with_token_transfers/2" do
    test "returns the transaction when there is token transfer from the given address" do
      address = insert(:address)
      token = insert(:token)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        from_address: address,
        transaction: transaction,
        token_contract_address: token.contract_address
      )

      result =
        address.hash
        |> Transaction.transactions_with_token_transfers(token.contract_address_hash)
        |> Repo.all()
        |> Enum.map(& &1.hash)

      assert result == [transaction.hash]
    end

    test "returns the transaction when there is token transfer to the given address" do
      address = insert(:address)
      token = insert(:token)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        to_address: address,
        transaction: transaction,
        token_contract_address: token.contract_address
      )

      result =
        address.hash
        |> Transaction.transactions_with_token_transfers(token.contract_address_hash)
        |> Repo.all()
        |> Enum.map(& &1.hash)

      assert result == [transaction.hash]
    end

    test "returns only transactions that have token transfers from the given token hash" do
      address = insert(:address)
      token = insert(:token)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      :transaction
      |> insert()
      |> with_block()

      insert(
        :token_transfer,
        to_address: address,
        transaction: transaction,
        token_contract_address: token.contract_address
      )

      insert(
        :token_transfer,
        to_address: address,
        transaction: transaction,
        token_contract_address: insert(:token).contract_address
      )

      result =
        address.hash
        |> Transaction.transactions_with_token_transfers(token.contract_address_hash)
        |> Repo.all()
        |> Enum.map(& &1.hash)

      assert result == [transaction.hash]
    end

    test "order the results DESC by block_number" do
      address = insert(:address)
      token = insert(:token)

      transaction_a =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1000))

      transaction_b =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1002))

      transaction_c =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1003))

      insert(
        :token_transfer,
        amount: 2,
        to_address: address,
        token_contract_address: token.contract_address,
        transaction: transaction_a
      )

      insert(
        :token_transfer,
        amount: 1,
        to_address: address,
        token_contract_address: token.contract_address,
        transaction: transaction_b
      )

      insert(
        :token_transfer,
        amount: 1,
        to_address: address,
        token_contract_address: token.contract_address,
        transaction: transaction_c
      )

      result =
        address.hash
        |> Transaction.transactions_with_token_transfers(token.contract_address_hash)
        |> Repo.all()
        |> Enum.map(& &1.block_number)

      assert result == [transaction_c.block_number, transaction_b.block_number, transaction_a.block_number]
    end
  end

  describe "transaction_hash_to_block_number/1" do
    test "returns only transactions with the specified block number" do
      target_block = insert(:block, number: 1_000_000)

      :transaction
      |> insert()
      |> with_block(target_block)

      :transaction
      |> insert()
      |> with_block(target_block)

      :transaction
      |> insert()
      |> with_block(insert(:block, number: 1_001_101))

      result =
        1_000_000
        |> Transaction.transactions_with_block_number()
        |> Repo.all()
        |> Enum.map(& &1.block_number)

      refute Enum.any?(result, fn block_number -> 1_001_101 == block_number end)
      assert Enum.all?(result, fn block_number -> 1_000_000 == block_number end)
    end
  end

  describe "last_nonce_by_address_query/1" do
    test "returns the nonce value from the last block" do
      address = insert(:address)

      :transaction
      |> insert(nonce: 100, from_address: address)
      |> with_block(insert(:block, number: 1000))

      :transaction
      |> insert(nonce: 300, from_address: address)
      |> with_block(insert(:block, number: 2000))

      last_nonce =
        address.hash
        |> Transaction.last_nonce_by_address_query()
        |> Repo.one()

      assert last_nonce == 300
    end

    test "considers only from_address in transactions" do
      address = insert(:address)

      :transaction
      |> insert(nonce: 100, to_address: address)
      |> with_block(insert(:block, number: 1000))

      last_nonce =
        address.hash
        |> Transaction.last_nonce_by_address_query()
        |> Repo.one()

      assert last_nonce == nil
    end
  end

  describe "decoded_input_data/1" do
    test "that a transaction that is not a contract call returns a commensurate error" do
      transaction = insert(:transaction)

      assert {:error, :not_a_contract_call} = Transaction.decoded_input_data(transaction, [])
    end

    test "that a contract call transaction that has no verified contract returns a commensurate error" do
      transaction =
        :transaction
        |> insert(to_address: insert(:contract_address), input: "0x1234567891")
        |> Repo.preload(to_address: :smart_contract)

      assert {:error, :contract_not_verified, []} = Transaction.decoded_input_data(transaction, [])
    end

    test "that a contract call transaction that has a verified contract returns the decoded input data" do
      TestHelper.get_all_proxies_implementation_zero_addresses()

      transaction =
        :transaction_to_verified_contract
        |> insert()
        |> Repo.preload(to_address: :smart_contract)

      assert {:ok, "60fe47b1", "set(uint256 x)", [{"x", "uint256", 50}]} =
               Transaction.decoded_input_data(transaction, [])
    end

    test "that a contract call will look up a match in contract_methods table" do
      TestHelper.get_all_proxies_implementation_zero_addresses()

      :transaction_to_verified_contract
      |> insert()
      |> Repo.preload(to_address: :smart_contract)

      contract = insert(:smart_contract, contract_code_md5: "123") |> Repo.preload(:address)

      input_data =
        "set(uint)"
        |> ABI.encode([10])
        |> Base.encode16(case: :lower)

      transaction =
        :transaction
        |> insert(to_address: contract.address, input: "0x" <> input_data)
        |> Repo.preload(to_address: :smart_contract)

      assert {:ok, "60fe47b1", "set(uint256 x)", [{"x", "uint256", 10}]} =
               Transaction.decoded_input_data(transaction, [])
    end

    test "arguments name in function call replaced with argN if it's empty string" do
      TestHelper.get_all_proxies_implementation_zero_addresses()

      contract =
        insert(:smart_contract,
          contract_code_md5: "123",
          abi: [
            %{
              "constant" => false,
              "inputs" => [%{"name" => "", "type" => "uint256"}],
              "name" => "set",
              "outputs" => [],
              "payable" => false,
              "stateMutability" => "nonpayable",
              "type" => "function"
            }
          ]
        )
        |> Repo.preload(:address)

      input_data =
        "set(uint)"
        |> ABI.encode([10])
        |> Base.encode16(case: :lower)

      transaction =
        :transaction
        |> insert(to_address: contract.address, input: "0x" <> input_data)
        |> Repo.preload(to_address: :smart_contract)

      assert {:ok, "60fe47b1", "set(uint256 arg0)", [{"arg0", "uint256", 10}]} =
               Transaction.decoded_input_data(transaction, [])
    end
  end

  describe "Poison.encode!/1" do
    test "encodes transaction input" do
      assert %{
               insert(:transaction)
               | input: %Explorer.Chain.Data{
                   bytes:
                     <<169, 5, 156, 187, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 193, 108, 45, 196, 42, 228, 149, 239, 119,
                       191, 128, 248>>
                 }
             }
             |> Poison.encode!()
    end
  end

  describe "address_to_transactions_tasks_range_of_blocks/2" do
    test "returns empty extremums if no transactions" do
      address = insert(:address)

      extremums = Transaction.address_to_transactions_tasks_range_of_blocks(address.hash, [])

      assert extremums == %{
               :min_block_number => nil,
               :max_block_number => 0
             }
    end

    test "returns correct extremums for from_address" do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block(insert(:block, number: 1000))

      extremums = Transaction.address_to_transactions_tasks_range_of_blocks(address.hash, [])

      assert extremums == %{
               :min_block_number => 1000,
               :max_block_number => 1000
             }
    end

    test "returns correct extremums for to_address" do
      address = insert(:address)

      :transaction
      |> insert(to_address: address)
      |> with_block(insert(:block, number: 1000))

      extremums = Transaction.address_to_transactions_tasks_range_of_blocks(address.hash, [])

      assert extremums == %{
               :min_block_number => 1000,
               :max_block_number => 1000
             }
    end

    test "returns correct extremums for created_contract_address" do
      address = insert(:address)

      :transaction
      |> insert(created_contract_address: address)
      |> with_block(insert(:block, number: 1000))

      extremums = Transaction.address_to_transactions_tasks_range_of_blocks(address.hash, [])

      assert extremums == %{
               :min_block_number => 1000,
               :max_block_number => 1000
             }
    end

    test "returns correct extremums for multiple number of transactions" do
      address = insert(:address)

      :transaction
      |> insert(created_contract_address: address)
      |> with_block(insert(:block, number: 1000))

      :transaction
      |> insert(created_contract_address: address)
      |> with_block(insert(:block, number: 999))

      :transaction
      |> insert(created_contract_address: address)
      |> with_block(insert(:block, number: 1003))

      :transaction
      |> insert(from_address: address)
      |> with_block(insert(:block, number: 1001))

      :transaction
      |> insert(from_address: address)
      |> with_block(insert(:block, number: 1004))

      :transaction
      |> insert(to_address: address)
      |> with_block(insert(:block, number: 1002))

      :transaction
      |> insert(to_address: address)
      |> with_block(insert(:block, number: 998))

      extremums = Transaction.address_to_transactions_tasks_range_of_blocks(address.hash, [])

      assert extremums == %{
               :min_block_number => 998,
               :max_block_number => 1004
             }
    end
  end

  describe "address_to_transactions_with_rewards/2" do
    test "without transactions" do
      %Address{hash: address_hash} = insert(:address)

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      assert [] == Transaction.address_to_transactions_with_rewards(address_hash)
    end

    test "with from transactions" do
      %Address{hash: address_hash} = address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      assert [transaction] ==
               Transaction.address_to_transactions_with_rewards(address_hash, direction: :from)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to transactions" do
      %Address{hash: address_hash} = address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      assert [transaction] ==
               Transaction.address_to_transactions_with_rewards(address_hash, direction: :to)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and direction: :from" do
      %Address{hash: address_hash} = address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      # only contains "from" transaction
      assert [transaction] ==
               Transaction.address_to_transactions_with_rewards(address_hash, direction: :from)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and direction: :to" do
      %Address{hash: address_hash} = address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      assert [transaction] ==
               Transaction.address_to_transactions_with_rewards(address_hash, direction: :to)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and no :direction option" do
      %Address{hash: address_hash} = address = insert(:address)
      block = insert(:block)

      transaction1 =
        :transaction
        |> insert(to_address: address)
        |> with_block(block)

      transaction2 =
        :transaction
        |> insert(from_address: address)
        |> with_block(block)

      assert [transaction2, transaction1] ==
               Transaction.address_to_transactions_with_rewards(address_hash)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "does not include non-contract-creation parent transactions" do
      transaction =
        %Transaction{} =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{created_contract_address: address} =
        insert(:internal_transaction_create,
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      assert [] == Transaction.address_to_transactions_with_rewards(address.hash)
    end

    test "returns transactions that have token transfers for the given to_address" do
      %Address{hash: address_hash} = address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address, to_address_hash: address.hash)
        |> with_block()

      insert(
        :token_transfer,
        to_address: address,
        transaction: transaction
      )

      assert [transaction.hash] ==
               Transaction.address_to_transactions_with_rewards(address_hash)
               |> Enum.map(& &1.hash)
    end

    test "with transactions can be paginated" do
      %Address{hash: address_hash} = address = insert(:address)

      second_page_hashes =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block()
        |> Enum.map(& &1.hash)

      %Transaction{block_number: block_number, index: index} =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      assert second_page_hashes ==
               address_hash
               |> Transaction.address_to_transactions_with_rewards(
                 paging_options: %PagingOptions{
                   key: {block_number, index},
                   page_size: 2
                 }
               )
               |> Enum.map(& &1.hash)
               |> Enum.reverse()
    end

    test "returns results in reverse chronological order by block number and transaction index" do
      %Address{hash: address_hash} = address = insert(:address)

      a_block = insert(:block, number: 6000)

      %Transaction{hash: first} =
        :transaction
        |> insert(to_address: address)
        |> with_block(a_block)

      %Transaction{hash: second} =
        :transaction
        |> insert(to_address: address)
        |> with_block(a_block)

      %Transaction{hash: third} =
        :transaction
        |> insert(to_address: address)
        |> with_block(a_block)

      %Transaction{hash: fourth} =
        :transaction
        |> insert(to_address: address)
        |> with_block(a_block)

      b_block = insert(:block, number: 2000)

      %Transaction{hash: fifth} =
        :transaction
        |> insert(to_address: address)
        |> with_block(b_block)

      %Transaction{hash: sixth} =
        :transaction
        |> insert(to_address: address)
        |> with_block(b_block)

      result =
        address_hash
        |> Transaction.address_to_transactions_with_rewards()
        |> Enum.map(& &1.hash)

      assert [fourth, third, second, first, sixth, fifth] == result
    end

    test "with emission rewards" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: true)

      Application.put_env(:explorer, Explorer.Chain.Block.Reward,
        validators_contract_address: "0x0000000000000000000000000000000000000005",
        keys_manager_contract_address: "0x0000000000000000000000000000000000000006"
      )

      consumer_pid = start_supervised!(Explorer.Chain.Fetcher.FetchValidatorInfoOnDemand)
      :erlang.trace(consumer_pid, true, [:receive])

      block = insert(:block)

      block_miner_hash_string = Base.encode16(block.miner_hash.bytes, case: :lower)
      block_miner_hash = block.miner_hash

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :validator
      )

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :emission_funds
      )

      # isValidator => true
      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [%{id: id, jsonrpc: "2.0", result: "0x0000000000000000000000000000000000000000000000000000000000000001"}]}
        end
      )

      # getPayoutByMining => 0x0000000000000000000000000000000000000001
      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok, [%{id: id, result: "0x000000000000000000000000" <> block_miner_hash_string}]}
        end
      )

      res = Transaction.address_to_transactions_with_rewards(block.miner.hash)
      assert [{_, _}] = res

      assert_receive {:trace, ^consumer_pid, :receive, {:"$gen_cast", {:fetch_or_update, ^block_miner_hash}}}, 1000
      :timer.sleep(500)

      on_exit(fn ->
        Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: false)

        Application.put_env(:explorer, Explorer.Chain.Block.Reward,
          validators_contract_address: nil,
          keys_manager_contract_address: nil
        )
      end)
    end

    test "with emission rewards and transactions" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: true)

      Application.put_env(:explorer, Explorer.Chain.Block.Reward,
        validators_contract_address: "0x0000000000000000000000000000000000000005",
        keys_manager_contract_address: "0x0000000000000000000000000000000000000006"
      )

      consumer_pid = start_supervised!(Explorer.Chain.Fetcher.FetchValidatorInfoOnDemand)
      :erlang.trace(consumer_pid, true, [:receive])

      block = insert(:block)

      block_miner_hash_string = Base.encode16(block.miner_hash.bytes, case: :lower)
      block_miner_hash = block.miner_hash

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :validator
      )

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :emission_funds
      )

      :transaction
      |> insert(to_address: block.miner)
      |> with_block(block)
      |> Repo.preload(:token_transfers)

      # isValidator => true
      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [%{id: id, jsonrpc: "2.0", result: "0x0000000000000000000000000000000000000000000000000000000000000001"}]}
        end
      )

      # getPayoutByMining => 0x0000000000000000000000000000000000000001
      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok, [%{id: id, result: "0x000000000000000000000000" <> block_miner_hash_string}]}
        end
      )

      assert [_, {_, _}] = Transaction.address_to_transactions_with_rewards(block.miner.hash, direction: :to)

      assert_receive {:trace, ^consumer_pid, :receive, {:"$gen_cast", {:fetch_or_update, ^block_miner_hash}}}, 1000
      :timer.sleep(500)

      on_exit(fn ->
        Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: false)

        Application.put_env(:explorer, Explorer.Chain.Block.Reward,
          validators_contract_address: nil,
          keys_manager_contract_address: nil
        )
      end)
    end

    test "with transactions if rewards are not in the range of blocks" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: true)

      block = insert(:block)

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :validator
      )

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :emission_funds
      )

      :transaction
      |> insert(from_address: block.miner)
      |> with_block()
      |> Repo.preload(:token_transfers)

      assert [_] = Transaction.address_to_transactions_with_rewards(block.miner.hash, direction: :from)

      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: false)
    end

    test "with emissions rewards, but feature disabled" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: false)

      block = insert(:block)

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :validator
      )

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :emission_funds
      )

      assert [] == Transaction.address_to_transactions_with_rewards(block.miner.hash)
    end
  end

  describe "fee/2" do
    test "is_nil(gas_price), is_nil(gas_used)" do
      assert {:maximum, nil} == Transaction.fee(%Transaction{gas: 100_500, gas_price: nil, gas_used: nil}, :wei)
    end

    test "not is_nil(gas_price), is_nil(gas_used)" do
      assert {:maximum, Decimal.new("20100000")} ==
               Transaction.fee(
                 %Transaction{gas: 100_500, gas_price: %Explorer.Chain.Wei{value: 200}, gas_used: nil},
                 :wei
               )
    end

    test "is_nil(gas_price), not is_nil(gas_used)" do
      transaction = %Transaction{
        gas_price: nil,
        max_priority_fee_per_gas: %Explorer.Chain.Wei{value: 10_000_000_000},
        max_fee_per_gas: %Explorer.Chain.Wei{value: 63_000_000_000},
        gas_used: Decimal.new(100),
        block: %{base_fee_per_gas: %Explorer.Chain.Wei{value: 42_000_000_000}}
      }

      if Application.get_env(:explorer, :chain_type) == :optimism do
        assert {:actual, nil} ==
                 Transaction.fee(
                   transaction,
                   :wei
                 )
      else
        assert {:actual, Decimal.new("5200000000000")} ==
                 Transaction.fee(
                   transaction,
                   :wei
                 )
      end
    end

    test "not is_nil(gas_price), not is_nil(gas_used)" do
      assert {:actual, Decimal.new("6")} ==
               Transaction.fee(
                 %Transaction{gas_price: %Explorer.Chain.Wei{value: 2}, gas_used: Decimal.new(3)},
                 :wei
               )
    end
  end

  describe "get_method_name/1" do
    test "returns method name for transaction with input data starting with 0x" do
      transaction =
        :transaction |> insert(input: "0x3078f1140ab0ba")

      assert "0x3078f114" == Transaction.get_method_name(transaction)
    end
  end
end
