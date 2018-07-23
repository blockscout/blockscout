defmodule Explorer.ChainTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{Chain, Factory, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Block, InternalTransaction, Log, SmartContract, Transaction, Wei}
  alias Explorer.Chain.Supply.ProofOfAuthority

  doctest Explorer.Chain

  describe "address_to_transaction_count/1" do
    test "without transactions" do
      address = insert(:address)

      assert Chain.address_to_transaction_count(address) == 0
    end

    test "with transactions" do
      %Transaction{from_address: address} = insert(:transaction) |> Repo.preload(:from_address)
      insert(:transaction, to_address: address)

      assert Chain.address_to_transaction_count(address) == 2
    end

    test "with contract creation transactions the contract address is counted" do
      address = insert(:address)

      insert(
        :internal_transaction_create,
        created_contract_address: address,
        index: 0,
        transaction: insert(:transaction, to_address: nil)
      )

      assert Chain.address_to_transaction_count(address) == 1
    end

    test "doesn't double count addresses when to_address = from_address" do
      %Transaction{from_address: address} = insert(:transaction) |> Repo.preload(:from_address)
      insert(:transaction, to_address: address, from_address: address)

      assert Chain.address_to_transaction_count(address) == 2
    end

    test "does not count non-contract-creation parent transactions" do
      transaction_with_to_address =
        %Transaction{} =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{created_contract_address: address} =
        insert(:internal_transaction_create, transaction: transaction_with_to_address, index: 0)

      assert Chain.address_to_transaction_count(address) == 0
    end
  end

  describe "address_to_transactions/2" do
    test "without transactions" do
      address = insert(:address)

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      assert [] == Chain.address_to_transactions(address)
    end

    test "with from transactions" do
      address = insert(:address)
      transaction = :transaction |> insert(from_address: address) |> with_block()

      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :from)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to transactions" do
      address = insert(:address)
      transaction = :transaction |> insert(to_address: address) |> with_block()

      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :to)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and direction: :from" do
      address = insert(:address)
      transaction = :transaction |> insert(from_address: address) |> with_block()
      :transaction |> insert(to_address: address) |> with_block()

      # only contains "from" transaction
      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :from)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and direction: :to" do
      address = insert(:address)
      transaction = :transaction |> insert(to_address: address) |> with_block()
      :transaction |> insert(from_address: address) |> with_block()

      # only contains "to" transaction
      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :to)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and no :direction option" do
      address = insert(:address)
      block = insert(:block)
      transaction1 = :transaction |> insert(to_address: address) |> with_block(block)
      transaction2 = :transaction |> insert(from_address: address) |> with_block(block)

      assert [transaction2, transaction1] ==
               Chain.address_to_transactions(address) |> Repo.preload([:block, :to_address, :from_address])
    end

    test "does not include non-contract-creation parent transactions" do
      transaction =
        %Transaction{} =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{created_contract_address: address} =
        insert(:internal_transaction_create, transaction: transaction, index: 0)

      assert [] == Chain.address_to_transactions(address)
    end

    test "with transactions can be paginated" do
      address = insert(:address)

      second_page_hashes =
        50
        |> insert_list(:transaction, from_address: address)
        |> with_block()
        |> Enum.map(& &1.hash)

      %Transaction{block_number: block_number, index: index} =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      assert second_page_hashes ==
               address
               |> Chain.address_to_transactions(
                 paging_options: %PagingOptions{key: {block_number, index}, page_size: 50}
               )
               |> Enum.map(& &1.hash)
               |> Enum.reverse()
    end
  end

  describe "balance/2" do
    test "with Address.t with :wei" do
      assert Chain.balance(%Address{fetched_balance: %Wei{value: Decimal.new(1)}}, :wei) == Decimal.new(1)
      assert Chain.balance(%Address{fetched_balance: nil}, :wei) == nil
    end

    test "with Address.t with :gwei" do
      assert Chain.balance(%Address{fetched_balance: %Wei{value: Decimal.new(1)}}, :gwei) == Decimal.new("1e-9")
      assert Chain.balance(%Address{fetched_balance: %Wei{value: Decimal.new("1e9")}}, :gwei) == Decimal.new(1)
      assert Chain.balance(%Address{fetched_balance: nil}, :gwei) == nil
    end

    test "with Address.t with :ether" do
      assert Chain.balance(%Address{fetched_balance: %Wei{value: Decimal.new(1)}}, :ether) == Decimal.new("1e-18")
      assert Chain.balance(%Address{fetched_balance: %Wei{value: Decimal.new("1e18")}}, :ether) == Decimal.new(1)
      assert Chain.balance(%Address{fetched_balance: nil}, :ether) == nil
    end
  end

  describe "block_to_transactions/2" do
    test "without transactions" do
      block = insert(:block)

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      assert [] = Chain.block_to_transactions(block)
    end

    test "with transactions" do
      %Transaction{block: block, hash: transaction_hash} =
        :transaction
        |> insert()
        |> with_block()

      assert [%Transaction{hash: ^transaction_hash}] = Chain.block_to_transactions(block)
    end

    test "with transactions can be paginated" do
      block = insert(:block)

      second_page_hashes =
        50
        |> insert_list(:transaction)
        |> with_block(block)
        |> Enum.map(& &1.hash)

      %Transaction{block_number: block_number, index: index} =
        :transaction
        |> insert()
        |> with_block(block)

      assert second_page_hashes ==
               block
               |> Chain.block_to_transactions(paging_options: %PagingOptions{key: {block_number, index}, page_size: 50})
               |> Enum.map(& &1.hash)
               |> Enum.reverse()
    end
  end

  describe "block_to_transaction_count/1" do
    test "without transactions" do
      block = insert(:block)

      assert Chain.block_to_transaction_count(block) == 0
    end

    test "with transactions" do
      %Transaction{block: block} =
        :transaction
        |> insert()
        |> with_block()

      assert Chain.block_to_transaction_count(block) == 1
    end
  end

  describe "confirmations/1" do
    test "with block.number == max_block_number " do
      block = insert(:block)
      {:ok, max_block_number} = Chain.max_block_number()

      assert block.number == max_block_number
      assert Chain.confirmations(block, max_block_number: max_block_number) == 0
    end

    test "with block.number < max_block_number" do
      block = insert(:block)
      max_block_number = block.number + 2

      assert block.number < max_block_number

      assert Chain.confirmations(block, max_block_number: max_block_number) == max_block_number - block.number
    end
  end

  describe "fee/2" do
    test "without receipt with :wei unit" do
      assert Chain.fee(%Transaction{gas: Decimal.new(3), gas_price: %Wei{value: Decimal.new(2)}, gas_used: nil}, :wei) ==
               {:maximum, Decimal.new(6)}
    end

    test "without receipt with :gwei unit" do
      assert Chain.fee(%Transaction{gas: Decimal.new(3), gas_price: %Wei{value: Decimal.new(2)}, gas_used: nil}, :gwei) ==
               {:maximum, Decimal.new("6e-9")}
    end

    test "without receipt with :ether unit" do
      assert Chain.fee(%Transaction{gas: Decimal.new(3), gas_price: %Wei{value: Decimal.new(2)}, gas_used: nil}, :ether) ==
               {:maximum, Decimal.new("6e-18")}
    end

    test "with receipt with :wei unit" do
      assert Chain.fee(
               %Transaction{
                 gas: Decimal.new(3),
                 gas_price: %Wei{value: Decimal.new(2)},
                 gas_used: Decimal.new(2)
               },
               :wei
             ) == {:actual, Decimal.new(4)}
    end

    test "with receipt with :gwei unit" do
      assert Chain.fee(
               %Transaction{
                 gas: Decimal.new(3),
                 gas_price: %Wei{value: Decimal.new(2)},
                 gas_used: Decimal.new(2)
               },
               :gwei
             ) == {:actual, Decimal.new("4e-9")}
    end

    test "with receipt with :ether unit" do
      assert Chain.fee(
               %Transaction{
                 gas: Decimal.new(3),
                 gas_price: %Wei{value: Decimal.new(2)},
                 gas_used: Decimal.new(2)
               },
               :ether
             ) == {:actual, Decimal.new("4e-18")}
    end
  end

  describe "gas_price/2" do
    test ":wei unit" do
      assert Chain.gas_price(%Transaction{gas_price: %Wei{value: Decimal.new(1)}}, :wei) == Decimal.new(1)
    end

    test ":gwei unit" do
      assert Chain.gas_price(%Transaction{gas_price: %Wei{value: Decimal.new(1)}}, :gwei) == Decimal.new("1e-9")

      assert Chain.gas_price(%Transaction{gas_price: %Wei{value: Decimal.new("1e9")}}, :gwei) == Decimal.new(1)
    end

    test ":ether unit" do
      assert Chain.gas_price(%Transaction{gas_price: %Wei{value: Decimal.new(1)}}, :ether) == Decimal.new("1e-18")

      assert Chain.gas_price(%Transaction{gas_price: %Wei{value: Decimal.new("1e18")}}, :ether) == Decimal.new(1)
    end
  end

  describe "hashes_to_addresses/1" do
    test "with existing addresses" do
      address1_attrs = %{hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      address2_attrs = %{hash: "0x6aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      address1 = insert(:address, address1_attrs)
      address2 = insert(:address, address2_attrs)
      hashes = [address1.hash, address2.hash]

      [found_address1, found_address2] = Explorer.Chain.hashes_to_addresses(hashes)

      %Explorer.Chain.Address{hash: found_hash1} = found_address1
      %Explorer.Chain.Address{hash: found_hash2} = found_address2

      assert found_hash1 == address1.hash
      assert found_hash2 == address2.hash
    end

    test "with nonexistent addresses" do
      hash1 = "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"
      hash2 = "0x6aaeb6053f3e94c9b9a09f33669435e7ef1beaed"
      hashes = [hash1, hash2]

      assert Explorer.Chain.hashes_to_addresses(hashes) == []
    end
  end

  describe "hash_to_transaction/2" do
    test "with transaction with block required without block returns {:error, :not_found}" do
      %Transaction{hash: hash_with_block} =
        :transaction
        |> insert()
        |> with_block()

      %Transaction{hash: hash_without_index} = insert(:transaction)

      assert {:ok, %Transaction{hash: ^hash_with_block}} =
               Chain.hash_to_transaction(
                 hash_with_block,
                 necessity_by_association: %{block: :required}
               )

      assert {:error, :not_found} =
               Chain.hash_to_transaction(
                 hash_without_index,
                 necessity_by_association: %{block: :required}
               )

      assert {:ok, %Transaction{hash: ^hash_without_index}} =
               Chain.hash_to_transaction(
                 hash_without_index,
                 necessity_by_association: %{block: :optional}
               )
    end

    test "created_contract_address_hash populated when existing" do
      transaction =
        %Transaction{hash: hash_with_block} =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{created_contract_address_hash: contract_hash} =
        insert(:internal_transaction_create, transaction: transaction, index: 0)

      assert {:ok, %Transaction{hash: ^hash_with_block, created_contract_address_hash: ^contract_hash}} =
               Chain.hash_to_transaction(
                 hash_with_block,
                 necessity_by_association: %{block: :required}
               )
    end

    test "transaction with multiple create internal transactions is returned" do
      transaction =
        %Transaction{hash: hash_with_block} =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction, transaction: transaction, index: 0)

      Enum.each(1..3, fn index ->
        insert(:internal_transaction_create, transaction: transaction, index: index)
      end)

      assert {:ok, %Transaction{hash: ^hash_with_block}} = Chain.hash_to_transaction(hash_with_block)
    end
  end

  describe "list_blocks/2" do
    test "without blocks" do
      assert [] = Chain.list_blocks()
    end

    test "with blocks" do
      %Block{hash: hash} = insert(:block)

      assert [%Block{hash: ^hash}] = Chain.list_blocks()
    end

    test "with blocks can be paginated" do
      second_page_block_ids =
        50
        |> insert_list(:block)
        |> Enum.map(& &1.number)

      block = insert(:block)

      assert second_page_block_ids ==
               [paging_options: %PagingOptions{key: {block.number}, page_size: 50}]
               |> Chain.list_blocks()
               |> Enum.map(& &1.number)
               |> Enum.reverse()
    end
  end

  describe "number_to_block/1" do
    test "without block" do
      assert {:error, :not_found} = Chain.number_to_block(-1)
    end

    test "with block" do
      %Block{number: number} = insert(:block)

      assert {:ok, %Block{number: ^number}} = Chain.number_to_block(number)
    end
  end

  describe "address_to_internal_transactions/1" do
    test "with single transaction containing two internal transactions" do
      address = insert(:address)
      transaction = insert(:transaction)

      %InternalTransaction{id: first_id} =
        insert(:internal_transaction, index: 0, transaction: transaction, to_address: address)

      %InternalTransaction{id: second_id} =
        insert(:internal_transaction, index: 1, transaction: transaction, to_address: address)

      result = address |> Chain.address_to_internal_transactions() |> Enum.map(& &1.id)
      assert Enum.member?(result, first_id)
      assert Enum.member?(result, second_id)
    end

    test "loads associations in necessity_by_association" do
      address = insert(:address)
      transaction = insert(:transaction, to_address: address)
      insert(:internal_transaction, transaction: transaction, to_address: address, index: 0)
      insert(:internal_transaction, transaction: transaction, to_address: address, index: 1)

      assert [
               %InternalTransaction{
                 from_address: %Ecto.Association.NotLoaded{},
                 to_address: %Ecto.Association.NotLoaded{},
                 transaction: %Transaction{}
               }
               | _
             ] = Chain.address_to_internal_transactions(address)

      assert [
               %InternalTransaction{
                 from_address: %Address{},
                 to_address: %Address{},
                 transaction: %Transaction{}
               }
               | _
             ] =
               Chain.address_to_internal_transactions(
                 address,
                 necessity_by_association: %{
                   from_address: :optional,
                   to_address: :optional,
                   transaction: :optional
                 }
               )
    end

    test "returns results in reverse chronological order by block number, transaction index, internal transaction index" do
      address = insert(:address)

      pending_transaction = insert(:transaction)

      %InternalTransaction{id: first_pending} =
        insert(
          :internal_transaction,
          transaction: pending_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: second_pending} =
        insert(
          :internal_transaction,
          transaction: pending_transaction,
          to_address: address,
          index: 1
        )

      a_block = insert(:block, number: 2000)

      first_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{id: first} =
        insert(
          :internal_transaction,
          transaction: first_a_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: second} =
        insert(
          :internal_transaction,
          transaction: first_a_transaction,
          to_address: address,
          index: 1
        )

      second_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{id: third} =
        insert(
          :internal_transaction,
          transaction: second_a_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: fourth} =
        insert(
          :internal_transaction,
          transaction: second_a_transaction,
          to_address: address,
          index: 1
        )

      b_block = insert(:block, number: 6000)

      first_b_transaction =
        :transaction
        |> insert()
        |> with_block(b_block)

      %InternalTransaction{id: fifth} =
        insert(
          :internal_transaction,
          transaction: first_b_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: sixth} =
        insert(
          :internal_transaction,
          transaction: first_b_transaction,
          to_address: address,
          index: 1
        )

      result =
        address
        |> Chain.address_to_internal_transactions()
        |> Enum.map(& &1.id)

      assert [second_pending, first_pending, sixth, fifth, fourth, third, second, first] == result
    end

    test "excludes internal transactions of type `call` when they are alone in the parent transaction" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      insert(:internal_transaction, index: 0, to_address: address, transaction: transaction)

      assert Enum.empty?(Chain.address_to_internal_transactions(address))
    end

    test "includes internal transactions of type `create` even when they are alone in the parent transaction" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      expected =
        insert(
          :internal_transaction_create,
          index: 0,
          from_address: address,
          transaction: transaction
        )

      actual = Enum.at(Chain.address_to_internal_transactions(address), 0)

      assert actual.id == expected.id
    end
  end

  describe "pending_transactions/0" do
    test "without transactions" do
      assert [] = Chain.recent_pending_transactions()
    end

    test "with transactions" do
      %Transaction{hash: hash} = insert(:transaction)

      assert [%Transaction{hash: ^hash}] = Chain.recent_pending_transactions()
    end

    test "with transactions can be paginated" do
      second_page_hashes =
        50
        |> insert_list(:transaction)
        |> Enum.map(& &1.hash)

      %Transaction{inserted_at: inserted_at, hash: hash} = insert(:transaction)

      assert second_page_hashes ==
               [paging_options: %PagingOptions{key: {inserted_at, hash}, page_size: 50}]
               |> Chain.recent_pending_transactions()
               |> Enum.map(& &1.hash)
               |> Enum.reverse()
    end
  end

  describe "transaction_to_internal_transactions/1" do
    test "with transaction without internal transactions" do
      transaction = insert(:transaction)

      assert [] = Chain.transaction_to_internal_transactions(transaction)
    end

    test "with transaction with internal transactions returns all internal transactions for a given transaction hash" do
      transaction = insert(:transaction)
      first = insert(:internal_transaction, transaction: transaction, index: 0)
      second = insert(:internal_transaction, transaction: transaction, index: 1)

      results =
        transaction
        |> Chain.transaction_to_internal_transactions()
        |> Enum.map(& &1.id)

      assert 2 == length(results)
      assert Enum.member?(results, first.id)
      assert Enum.member?(results, second.id)
    end

    test "with transaction with internal transactions loads associations with in necessity_by_association" do
      transaction = insert(:transaction)
      insert(:internal_transaction_create, transaction: transaction, index: 0)

      assert [
               %InternalTransaction{
                 from_address: %Ecto.Association.NotLoaded{},
                 to_address: %Ecto.Association.NotLoaded{},
                 transaction: %Ecto.Association.NotLoaded{}
               }
             ] = Chain.transaction_to_internal_transactions(transaction)

      assert [
               %InternalTransaction{
                 from_address: %Address{},
                 to_address: nil,
                 transaction: %Transaction{}
               }
             ] =
               Chain.transaction_to_internal_transactions(
                 transaction,
                 necessity_by_association: %{
                   from_address: :optional,
                   to_address: :optional,
                   transaction: :optional
                 }
               )
    end

    test "excludes internal transaction of type call with no siblings in the transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction, transaction: transaction, index: 0)

      result = Chain.transaction_to_internal_transactions(transaction)

      assert Enum.empty?(result)
    end

    test "includes internal transactions of type `create` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected = insert(:internal_transaction_create, index: 0, transaction: transaction)

      actual = Enum.at(Chain.transaction_to_internal_transactions(transaction), 0)

      assert actual.id == expected.id
    end

    test "returns the internal transactions in ascending index order" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{id: first_id} = insert(:internal_transaction, transaction: transaction, index: 0)
      %InternalTransaction{id: second_id} = insert(:internal_transaction, transaction: transaction, index: 1)

      result =
        transaction
        |> Chain.transaction_to_internal_transactions()
        |> Enum.map(& &1.id)

      assert [first_id, second_id] == result
    end
  end

  describe "transaction_to_logs/2" do
    test "without logs" do
      transaction = insert(:transaction)

      assert [] = Chain.transaction_to_logs(transaction)
    end

    test "with logs" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %Log{id: id} = insert(:log, transaction: transaction)

      assert [%Log{id: ^id}] = Chain.transaction_to_logs(transaction)
    end

    test "with logs can be paginated" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      log = insert(:log, transaction: transaction, index: 1)

      second_page_indexes =
        2..51
        |> Enum.map(fn index -> insert(:log, transaction: transaction, index: index) end)
        |> Enum.map(& &1.index)

      assert second_page_indexes ==
               transaction
               |> Chain.transaction_to_logs(paging_options: %PagingOptions{key: {log.index}, page_size: 50})
               |> Enum.map(& &1.index)
    end

    test "with logs necessity_by_association loads associations" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:log, transaction: transaction)

      assert [%Log{address: %Address{}, transaction: %Transaction{}}] =
               Chain.transaction_to_logs(
                 transaction,
                 necessity_by_association: %{
                   address: :optional,
                   transaction: :optional
                 }
               )

      assert [
               %Log{
                 address: %Ecto.Association.NotLoaded{},
                 transaction: %Ecto.Association.NotLoaded{}
               }
             ] = Chain.transaction_to_logs(transaction)
    end
  end

  describe "value/2" do
    test "with InternalTransaction.t with :wei" do
      assert Chain.value(%InternalTransaction{value: %Wei{value: Decimal.new(1)}}, :wei) == Decimal.new(1)
    end

    test "with InternalTransaction.t with :gwei" do
      assert Chain.value(%InternalTransaction{value: %Wei{value: Decimal.new(1)}}, :gwei) == Decimal.new("1e-9")

      assert Chain.value(%InternalTransaction{value: %Wei{value: Decimal.new("1e9")}}, :gwei) == Decimal.new(1)
    end

    test "with InternalTransaction.t with :ether" do
      assert Chain.value(%InternalTransaction{value: %Wei{value: Decimal.new(1)}}, :ether) == Decimal.new("1e-18")

      assert Chain.value(%InternalTransaction{value: %Wei{value: Decimal.new("1e18")}}, :ether) == Decimal.new(1)
    end

    test "with Transaction.t with :wei" do
      assert Chain.value(%Transaction{value: %Wei{value: Decimal.new(1)}}, :wei) == Decimal.new(1)
    end

    test "with Transaction.t with :gwei" do
      assert Chain.value(%Transaction{value: %Wei{value: Decimal.new(1)}}, :gwei) == Decimal.new("1e-9")
      assert Chain.value(%Transaction{value: %Wei{value: Decimal.new("1e9")}}, :gwei) == Decimal.new(1)
    end

    test "with Transaction.t with :ether" do
      assert Chain.value(%Transaction{value: %Wei{value: Decimal.new(1)}}, :ether) == Decimal.new("1e-18")
      assert Chain.value(%Transaction{value: %Wei{value: Decimal.new("1e18")}}, :ether) == Decimal.new(1)
    end
  end

  describe "find_contract_address/1" do
    test "doesn't find an address that doesn't have a code" do
      address = insert(:address, contract_code: nil)

      response = Chain.find_contract_address(address.hash)

      assert {:error, :not_found} == response
    end

    test "doesn't find a unexistent address" do
      unexistent_address_hash = Factory.address_hash()

      response = Chain.find_contract_address(unexistent_address_hash)

      assert {:error, :not_found} == response
    end

    test "finds an contract address" do
      address =
        insert(:address, contract_code: Factory.data("contract_code"), smart_contract: nil)
        |> Repo.preload(:contracts_creation_internal_transaction)

      response = Chain.find_contract_address(address.hash)

      assert response == {:ok, address}
    end
  end

  describe "block_reward/1" do
    setup do
      %{block_range: range} = block_reward = insert(:block_reward)

      block = insert(:block, number: Enum.random(Range.new(range.from, range.to)))
      insert(:transaction)

      {:ok, block: block, block_reward: block_reward}
    end

    test "with block containing transactions", %{block: block, block_reward: block_reward} do
      :transaction
      |> insert(gas_price: 1)
      |> with_block(block, gas_used: 1)

      :transaction
      |> insert(gas_price: 1)
      |> with_block(block, gas_used: 2)

      expected =
        block_reward.reward
        |> Wei.to(:wei)
        |> Decimal.add(Decimal.new(3))
        |> Wei.from(:wei)

      assert expected == Chain.block_reward(block)
    end

    test "with block without transactions", %{block: block, block_reward: block_reward} do
      assert block_reward.reward == Chain.block_reward(block)
    end
  end

  describe "recent_collated_transactions/1" do
    test "with no collated transactions it returns an empty list" do
      assert [] == Explorer.Chain.recent_collated_transactions()
    end

    test "it excludes pending transactions" do
      insert(:transaction)
      assert [] == Explorer.Chain.recent_collated_transactions()
    end

    test "it has contract_creation_address_hash added" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{created_contract_address_hash: hash} =
        insert(:internal_transaction_create, transaction: transaction, index: 0)

      assert [%Transaction{created_contract_address_hash: ^hash}] = Explorer.Chain.recent_collated_transactions()
    end
  end

  describe "smart_contract_bytecode/1" do
    test "fetches the smart contract bytecode" do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      created_contract_address = insert(:address, contract_code: smart_contract_bytecode)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :internal_transaction_create,
        transaction: transaction,
        index: 0,
        created_contract_address: created_contract_address,
        created_contract_code: smart_contract_bytecode
      )

      assert Chain.smart_contract_bytecode(created_contract_address.hash) == smart_contract_bytecode
    end
  end

  describe "create_smart_contract/1" do
    test "with valid data creates a smart contract" do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      created_contract_address =
        insert(
          :address,
          hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
          contract_code: smart_contract_bytecode
        )

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :internal_transaction_create,
        transaction: transaction,
        index: 0,
        created_contract_address: created_contract_address,
        created_contract_code: smart_contract_bytecode
      )

      valid_attrs = %{
        address_hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
        name: "SimpleStorage",
        compiler_version: "0.4.23",
        optimization: false,
        contract_source_code:
          "pragma solidity ^0.4.23; contract SimpleStorage {uint storedData; function set(uint x) public {storedData = x; } function get() public constant returns (uint) {return storedData; } }",
        abi: [
          %{
            "constant" => false,
            "inputs" => [%{"name" => "x", "type" => "uint256"}],
            "name" => "set",
            "outputs" => [],
            "payable" => false,
            "stateMutability" => "nonpayable",
            "type" => "function"
          },
          %{
            "constant" => true,
            "inputs" => [],
            "name" => "get",
            "outputs" => [%{"name" => "", "type" => "uint256"}],
            "payable" => false,
            "stateMutability" => "view",
            "type" => "function"
          }
        ]
      }

      assert {:ok, %SmartContract{} = smart_contract} = Chain.create_smart_contract(valid_attrs)
      assert smart_contract.name == "SimpleStorage"
      assert smart_contract.compiler_version == "0.4.23"
      assert smart_contract.optimization == false
      assert smart_contract.contract_source_code != ""
      assert smart_contract.abi != ""
    end
  end

  describe "import_internal_transactions/1" do
    test "updates address with contract code" do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      address_hash = "0x1c494fa496f1cfd918b5ff190835af3aaf60987e"
      insert(:address, hash: address_hash)

      from_address_hash = "0x8cc2e4b51b4340cb3727cffe3f1878756e732cee"
      from_address = insert(:address, hash: from_address_hash)

      transaction_string_hash = "0x0705ea0a5b997d9aafd5c531e016d9aabe3297a28c0bd4ef005fe6ea329d301b"
      insert(:transaction, from_address: from_address, hash: transaction_string_hash)

      options = [
        addresses: [
          params: [
            %{
              contract_code: smart_contract_bytecode,
              hash: address_hash
            }
          ]
        ],
        internal_transactions: [
          params: [
            %{
              created_contract_address_hash: address_hash,
              created_contract_code: smart_contract_bytecode,
              from_address_hash: from_address_hash,
              gas: 184_531,
              gas_used: 84531,
              index: 0,
              init:
                "0x6060604052341561000c57fe5b5b6101a68061001c6000396000f300606060405263ffffffff7c01000000000000000000000000000000000000000000000000000000006000350416631d3b9edf811461005b57806366098d4f1461007b578063a12f69e01461009b578063f4f3bdc1146100bb575bfe5b6100696004356024356100db565b60408051918252519081900360200190f35b61006960043560243561010a565b60408051918252519081900360200190f35b610069600435602435610124565b60408051918252519081900360200190f35b610069600435602435610163565b60408051918252519081900360200190f35b60008282028315806100f757508284828115156100f457fe5b04145b15156100ff57fe5b8091505b5092915050565b6000828201838110156100ff57fe5b8091505b5092915050565b60008080831161013057fe5b828481151561013b57fe5b049050828481151561014957fe5b0681840201841415156100ff57fe5b8091505b5092915050565b60008282111561016f57fe5b508082035b929150505600a165627a7a7230582020c944d8375ca14e2c92b14df53c2d044cb99dc30c3ba9f55e2bcde87bd4709b0029",
              trace_address: [],
              transaction_hash: transaction_string_hash,
              type: "create",
              value: 0
            }
          ]
        ],
        transactions: [
          hashes: [transaction_string_hash]
        ]
      ]

      assert {:ok, _} = Chain.import_internal_transactions(options)

      address = Explorer.Repo.one(from(address in Explorer.Chain.Address, where: address.hash == ^address_hash))

      assert address.contract_code != nil
    end
  end

  test "total_supply/0" do
    height = 2_000_000
    insert(:block, number: height)
    expected = ProofOfAuthority.initial_supply() + height

    assert Chain.total_supply() == expected
  end

  test "circulating_supply/0" do
    assert Chain.circulating_supply() == ProofOfAuthority.circulating()
  end

  describe "address_hash_to_smart_contract/1" do
    test "fetches a smart contract" do
      smart_contract = insert(:smart_contract)

      assert ^smart_contract = Chain.address_hash_to_smart_contract(smart_contract.address_hash)
    end
  end

  test "subscribe_to_events/1" do
    assert :ok == Chain.subscribe_to_events(:logs)
    current_pid = self()
    assert [{^current_pid, _}] = Registry.lookup(Registry.ChainEvents, :logs)
  end

  describe "import_blocks" do
    @import_data [
      blocks: [
        params: [
          %{
            difficulty: 340_282_366_920_938_463_463_374_607_431_768_211_454,
            gas_limit: 6_946_336,
            gas_used: 50450,
            hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            nonce: 0,
            number: 37,
            parent_hash: "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
            size: 719,
            timestamp: Timex.parse!("2017-12-15T21:06:30.000000Z", "{ISO:Extended:Z}"),
            total_difficulty: 12_590_447_576_074_723_148_144_860_474_975_121_280_509
          }
        ]
      ],
      internal_transactions: [
        params: [
          %{
            call_type: "call",
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_677_320,
            gas_used: 27770,
            index: 0,
            output: "0x",
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            trace_address: [],
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "call",
            value: 0
          }
        ]
      ],
      logs: [
        params: [
          %{
            address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            data: "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
            first_topic: "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22",
            fourth_topic: nil,
            index: 0,
            second_topic: nil,
            third_topic: nil,
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "mined"
          }
        ]
      ],
      transactions: [
        on_conflict: :replace_all,
        params: [
          %{
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            block_number: 37,
            cumulative_gas_used: 50450,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_700_000,
            gas_price: 100_000_000_000,
            gas_used: 50450,
            hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            index: 0,
            input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
            nonce: 4,
            public_key:
              "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
            r: 0xA7F8F45CCE375BB7AF8750416E1B03E0473F93C256DA2285D1134FC97A700E01,
            s: 0x1F87A076F13824F4BE8963E3DFFD7300DAE64D5F23C9A062AF0C6EAD347C135F,
            standard_v: 1,
            status: :ok,
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            v: 0xBE,
            value: 0
          }
        ]
      ],
      addresses: [
        params: [
          %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"},
          %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"}
        ]
      ]
    ]

    test "publishes block data to subscribers on insert" do
      Chain.subscribe_to_events(:blocks)
      Chain.import_blocks(@import_data)
      assert_received {:chain_event, :blocks, [%Block{}]}
    end

    test "publishes log data to subscribers on insert" do
      Chain.subscribe_to_events(:logs)
      Chain.import_blocks(@import_data)
      assert_received {:chain_event, :logs, [%Log{}]}
    end
  end

  test "publishes update_balance data to subscribers on upsert" do
    address = insert(:address, fetched_balance: 3, fetched_balance_block_number: 3)
    Chain.subscribe_to_events(:balance_updates)
    Chain.update_balances([Map.from_struct(address)])

    assert_received {:chain_event, :balance_updates, [^address]}
  end
end
