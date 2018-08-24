defmodule Explorer.ChainTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{Chain, Factory, PagingOptions, Repo}

  alias Explorer.Chain.{
    Address,
    Block,
    InternalTransaction,
    Log,
    Token,
    TokenTransfer,
    Transaction,
    SmartContract,
    Wei
  }

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

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :from)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to transactions" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :to)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and direction: :from" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      # only contains "from" transaction
      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :from)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and direction: :to" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :to)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and no :direction option" do
      address = insert(:address)
      block = insert(:block)

      transaction1 =
        :transaction
        |> insert(to_address: address)
        |> with_block(block)
        |> Repo.preload(:token_transfers)

      transaction2 =
        :transaction
        |> insert(from_address: address)
        |> with_block(block)
        |> Repo.preload(:token_transfers)

      assert [transaction2, transaction1] ==
               Chain.address_to_transactions(address)
               |> Repo.preload([:block, :to_address, :from_address])
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

    test "returns transactions that have token transfers for the given to_address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer, to_address: address, transaction: transaction)

      transaction =
        Transaction
        |> Repo.get!(transaction.hash)
        |> Repo.preload([:block, :to_address, :from_address, token_transfers: :token])

      assert [transaction.hash] ==
               Chain.address_to_transactions(address)
               |> Enum.map(& &1.hash)
    end

    test "returns just the token transfers related to the given address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer = insert(:token_transfer, to_address: address, transaction: transaction)
      insert(:token_transfer, to_address: build(:address), transaction: transaction)

      transaction = Chain.address_to_transactions(address) |> List.first()
      assert transaction.token_transfers |> Enum.map(& &1.id) == [token_transfer.id]
    end

    test "returns just the token transfers related to the given contract address" do
      contract_address = insert(:address, contract_code: Factory.data("contract_code"))

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer = insert(:token_transfer, to_address: contract_address, transaction: transaction)
      insert(:token_transfer, to_address: build(:address), transaction: transaction)

      transaction = Chain.address_to_transactions(contract_address) |> List.first()
      assert Enum.map(transaction.token_transfers, & &1.id) == [token_transfer.id]
    end

    test "returns all token transfers when the given address is the token contract address" do
      contract_address = insert(:address, contract_code: Factory.data("contract_code"))

      transaction =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        token_contract_address: contract_address,
        transaction: transaction
      )

      insert(
        :token_transfer,
        to_address: build(:address),
        token_contract_address: contract_address,
        transaction: transaction
      )

      transaction = Chain.address_to_transactions(contract_address) |> List.first()
      assert Enum.count(transaction.token_transfers) == 2
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

  describe "hashes_to_transactions/2" do
    test "with transaction with block required without block returns nil" do
      [%Transaction{hash: hash_with_block1}, %Transaction{hash: hash_with_block2}] =
        2
        |> insert_list(:transaction)
        |> with_block()

      [%Transaction{hash: hash_without_index1}, %Transaction{hash: hash_without_index2}] = insert_list(2, :transaction)

      assert [%Transaction{hash: ^hash_with_block2}, %Transaction{hash: ^hash_with_block1}] =
               Chain.hashes_to_transactions(
                 [hash_with_block1, hash_with_block2],
                 necessity_by_association: %{block: :required}
               )

      assert [] =
               Chain.hashes_to_transactions(
                 [hash_without_index1, hash_without_index2],
                 necessity_by_association: %{block: :required}
               )

      assert [hash_without_index1, hash_without_index2]
             |> Chain.hashes_to_transactions(necessity_by_association: %{block: :optional})
             |> Enum.all?(&(&1.hash in [hash_without_index1, hash_without_index2]))
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

    test "includes internal transactions of type `reward` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected = insert(:internal_transaction, index: 0, transaction: transaction, type: :reward)

      actual = Enum.at(Chain.transaction_to_internal_transactions(transaction), 0)

      assert actual.id == expected.id
    end

    test "includes internal transactions of type `suicide` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected = insert(:internal_transaction, index: 0, transaction: transaction, gas: nil, type: :suicide)

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

  describe "transaction_to_token_transfers/2" do
    test "without token transfers" do
      transaction = insert(:transaction)

      assert [] = Chain.transaction_to_token_transfers(transaction)
    end

    test "with token transfers" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %TokenTransfer{id: id} = insert(:token_transfer, transaction: transaction)

      assert [%TokenTransfer{id: ^id}] = Chain.transaction_to_token_transfers(transaction)
    end

    test "token transfers necessity_by_association loads associations" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer, transaction: transaction)

      assert [%TokenTransfer{token: %Token{}, transaction: %Transaction{}}] =
               Chain.transaction_to_token_transfers(
                 transaction,
                 necessity_by_association: %{
                   token: :optional,
                   transaction: :optional
                 }
               )

      assert [
               %TokenTransfer{
                 token: %Ecto.Association.NotLoaded{},
                 transaction: %Ecto.Association.NotLoaded{}
               }
             ] = Chain.transaction_to_token_transfers(transaction)
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
    setup do
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

      {:ok, valid_attrs: valid_attrs, address: created_contract_address}
    end

    test "with valid data creates a smart contract", %{valid_attrs: valid_attrs} do
      assert {:ok, %SmartContract{} = smart_contract} = Chain.create_smart_contract(valid_attrs)
      assert smart_contract.name == "SimpleStorage"
      assert smart_contract.compiler_version == "0.4.23"
      assert smart_contract.optimization == false
      assert smart_contract.contract_source_code != ""
      assert smart_contract.abi != ""

      assert Repo.get_by(Address.Name,
               address_hash: smart_contract.address_hash,
               name: smart_contract.name,
               primary: true
             )
    end

    test "clears an existing primary name and sets the new one", %{valid_attrs: valid_attrs, address: address} do
      insert(:address_name, address: address, primary: true)
      assert {:ok, %SmartContract{} = smart_contract} = Chain.create_smart_contract(valid_attrs)

      assert Repo.get_by(Address.Name,
               address_hash: smart_contract.address_hash,
               name: smart_contract.name,
               primary: true
             )
    end
  end

  describe "stream_unfetched_balances/2" do
    test "with `t:Explorer.Chain.Balance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Block.t/0` `miner_hash`" do
      %Address{hash: miner_hash} = miner = insert(:address)
      %Block{number: block_number} = insert(:block, miner: miner)
      balance = insert(:unfetched_balance, address_hash: miner_hash, block_number: block_number)

      assert {:ok, [%{address_hash: ^miner_hash, block_number: ^block_number}]} =
               Chain.stream_unfetched_balances([], &[&1 | &2])

      update_balance_value(balance, 1)

      assert {:ok, []} = Chain.stream_unfetched_balances([], &[&1 | &2])
    end

    test "with `t:Explorer.Chain.Balance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Transaction.t/0` `from_address_hash`" do
      %Address{hash: from_address_hash} = from_address = insert(:address)
      %Block{number: block_number} = block = insert(:block)

      :transaction
      |> insert(from_address: from_address)
      |> with_block(block)

      balance = insert(:unfetched_balance, address_hash: from_address_hash, block_number: block_number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: from_address_hash, block_number: block_number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: from_address_hash, block_number: block_number} in balance_fields_list
    end

    test "with `t:Explorer.Chain.Balance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Transaction.t/0` `to_address_hash`" do
      %Address{hash: to_address_hash} = to_address = insert(:address)
      %Block{number: block_number} = block = insert(:block)

      :transaction
      |> insert(to_address: to_address)
      |> with_block(block)

      balance = insert(:unfetched_balance, address_hash: to_address_hash, block_number: block_number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: to_address_hash, block_number: block_number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: to_address_hash, block_number: block_number} in balance_fields_list
    end

    test "with `t:Explorer.Chain.Balance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Log.t/0` `address_hash`" do
      address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:log, address: address, transaction: transaction)

      balance = insert(:unfetched_balance, address_hash: address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{
               address_hash: address.hash,
               block_number: block.number
             } in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{
               address_hash: address.hash,
               block_number: block.number
             } in balance_fields_list
    end

    test "with `t:Explorer.Chain.Balance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.InternalTransaction.t/0` `created_contract_address_hash`" do
      created_contract_address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        created_contract_address: created_contract_address,
        index: 0,
        transaction: transaction
      )

      balance = insert(:unfetched_balance, address_hash: created_contract_address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{
               address_hash: created_contract_address.hash,
               block_number: block.number
             } in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{
               address_hash: created_contract_address.hash,
               block_number: block.number
             } in balance_fields_list
    end

    test "with `t:Explorer.Chain.Balance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.InternalTransaction.t/0` `from_address_hash`" do
      from_address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        from_address: from_address,
        index: 0,
        transaction: transaction
      )

      balance = insert(:unfetched_balance, address_hash: from_address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: from_address.hash, block_number: block.number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: from_address.hash, block_number: block.number} in balance_fields_list
    end

    test "with `t:Explorer.Chain.Balance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.InternalTransaction.t/0` `to_address_hash`" do
      to_address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        to_address: to_address,
        index: 0,
        transaction: transaction
      )

      balance = insert(:unfetched_balance, address_hash: to_address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: to_address.hash, block_number: block.number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: to_address.hash, block_number: block.number} in balance_fields_list
    end

    test "an address_hash used for multiple block_numbers returns all block_numbers" do
      miner = insert(:address)
      mined_block = insert(:block, miner: miner)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: mined_block.number)

      from_transaction_block = insert(:block)

      :transaction
      |> insert(from_address: miner)
      |> with_block(from_transaction_block)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: from_transaction_block.number)

      to_transaction_block = insert(:block)

      :transaction
      |> insert(to_address: miner)
      |> with_block(to_transaction_block)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: to_transaction_block.number)

      log_block = insert(:block)

      log_transaction =
        :transaction
        |> insert()
        |> with_block(log_block)

      insert(:log, address: miner, transaction: log_transaction)
      insert(:unfetched_balance, address_hash: miner.hash, block_number: log_block.number)

      from_internal_transaction_block = insert(:block)

      from_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(from_internal_transaction_block)

      insert(
        :internal_transaction_create,
        from_address: miner,
        index: 0,
        transaction: from_internal_transaction_transaction
      )

      insert(:unfetched_balance, address_hash: miner.hash, block_number: from_internal_transaction_block.number)

      to_internal_transaction_block = insert(:block)

      to_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(to_internal_transaction_block)

      insert(
        :internal_transaction_create,
        index: 0,
        to_address: miner,
        transaction: to_internal_transaction_transaction
      )

      insert(:unfetched_balance, address_hash: miner.hash, block_number: to_internal_transaction_block.number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      balance_fields_list_by_address_hash = Enum.group_by(balance_fields_list, & &1.address_hash)

      assert balance_fields_list_by_address_hash[miner.hash] |> Enum.map(& &1.block_number) |> Enum.sort() ==
               Enum.sort([
                 to_internal_transaction_block.number,
                 from_internal_transaction_block.number,
                 log_block.number,
                 to_transaction_block.number,
                 from_transaction_block.number,
                 mined_block.number
               ])
    end

    test "an address_hash used for the same block_number is only returned once" do
      miner = insert(:address)
      block = insert(:block, miner: miner)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: block.number)

      :transaction
      |> insert(from_address: miner)
      |> with_block(block)

      :transaction
      |> insert(to_address: miner)
      |> with_block(block)

      log_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:log, address: miner, transaction: log_transaction)

      from_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        from_address: miner,
        index: 0,
        transaction: from_internal_transaction_transaction
      )

      to_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        to_address: miner,
        index: 0,
        transaction: to_internal_transaction_transaction
      )

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      balance_fields_list_by_address_hash = Enum.group_by(balance_fields_list, & &1.address_hash)

      assert balance_fields_list_by_address_hash[miner.hash] |> Enum.map(& &1.block_number) |> Enum.sort() == [
               block.number
             ]
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

  describe "token_from_address_hash/1" do
    test "with valid hash" do
      token = insert(:token)
      assert {:ok, result} = Chain.token_from_address_hash(token.contract_address.hash)
      assert result.contract_address_hash == token.contract_address_hash
    end

    test "with hash that doesn't exist" do
      token = build(:token)
      assert {:error, :not_found} = Chain.token_from_address_hash(token.contract_address.hash)
    end
  end

  test "stream_uncataloged_token_contract_address_hashes/2 reduces with given reducer and accumulator" do
    insert(:token, cataloged: true)
    %Token{contract_address_hash: uncatalog_address} = insert(:token, cataloged: false)
    assert Chain.stream_uncataloged_token_contract_address_hashes([], &[&1 | &2]) == {:ok, [uncatalog_address]}
  end

  describe "transaction_has_token_transfers?/1" do
    test "returns true if transaction has token transfers" do
      transaction = insert(:transaction)
      insert(:token_transfer, transaction: transaction)

      assert Chain.transaction_has_token_transfers?(transaction.hash) == true
    end

    test "returns false if transaction has no token transfers" do
      transaction = insert(:transaction)

      assert Chain.transaction_has_token_transfers?(transaction.hash) == false
    end
  end

  describe "fetch_tokens_from_address_hash/1" do
    test "only returns tokens that a given address has interacted with" do
      alice = insert(:address)

      token_a =
        :token
        |> insert(name: "token-1")
        |> Repo.preload(:contract_address)

      token_b =
        :token
        |> insert(name: "token-2")
        |> Repo.preload(:contract_address)

      token_c =
        :token
        |> insert(name: "token-3")
        |> Repo.preload(:contract_address)

      insert(
        :token_transfer,
        token_contract_address: token_a.contract_address,
        from_address: alice,
        to_address: build(:address)
      )

      insert(
        :token_transfer,
        token_contract_address: token_b.contract_address,
        from_address: build(:address),
        to_address: alice
      )

      insert(
        :token_transfer,
        token_contract_address: token_c.contract_address,
        from_address: build(:address),
        to_address: build(:address)
      )

      expected_tokens =
        alice.hash
        |> Chain.fetch_tokens_from_address_hash()
        |> Enum.map(& &1.name)

      assert expected_tokens == [token_a.name, token_b.name]
    end

    test "returns a empty list when the given address hasn't interacted with one" do
      alice = insert(:address)

      token =
        :token
        |> insert(name: "token-1")
        |> Repo.preload(:contract_address)

      insert(
        :token_transfer,
        token_contract_address: token.contract_address,
        from_address: build(:address),
        to_address: build(:address)
      )

      assert Chain.fetch_tokens_from_address_hash(alice.hash) == []
    end

    test "distinct tokens by contract_address_hash" do
      alice = insert(:address)

      token =
        :token
        |> insert(name: "token-1")
        |> Repo.preload(:contract_address)

      insert(
        :token_transfer,
        token_contract_address: token.contract_address,
        from_address: alice,
        to_address: build(:address)
      )

      insert(
        :token_transfer,
        token_contract_address: token.contract_address,
        from_address: build(:address),
        to_address: alice
      )

      expected_tokens =
        alice.hash
        |> Chain.fetch_tokens_from_address_hash()
        |> Enum.map(& &1.name)

      assert expected_tokens == [token.name]
    end
  end

  describe "update_token/2" do
    test "updates a token's values" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        name: "Hodl Token",
        symbol: "HT",
        total_supply: 10,
        decimals: 1,
        cataloged: true
      }

      assert {:ok, updated_token} = Chain.update_token(token, update_params)
      assert updated_token.name == update_params.name
      assert updated_token.symbol == update_params.symbol
      assert updated_token.total_supply == Decimal.new(update_params.total_supply)
      assert updated_token.decimals == update_params.decimals
      assert updated_token.cataloged
    end
  end

  test "inserts an address name record when token has a name in params" do
    token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

    update_params = %{
      name: "Hodl Token",
      symbol: "HT",
      total_supply: 10,
      decimals: 1,
      cataloged: true
    }

    Chain.update_token(token, update_params)
    assert Repo.get_by(Address.Name, name: update_params.name, address_hash: token.contract_address_hash)
  end

  test "does not insert address name record when token doesn't have name in params" do
    token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

    update_params = %{
      cataloged: true
    }

    Chain.update_token(token, update_params)
    refute Repo.get_by(Address.Name, address_hash: token.contract_address_hash)
  end
end
