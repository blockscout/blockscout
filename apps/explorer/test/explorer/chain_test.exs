defmodule Explorer.ChainTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{Chain, Repo, Factory}

  alias Explorer.Chain.{Address, Block, InternalTransaction, Log, Transaction, Wei, SmartContract}

  doctest Explorer.Chain

  describe "address_to_transaction_count/1" do
    test "without transactions" do
      address = insert(:address)

      assert Chain.address_to_transaction_count(address) == 0
    end

    test "with transactions" do
      %Transaction{from_address_hash: address_hash} = insert(:transaction)
      insert(:transaction, to_address_hash: address_hash)
      address = Repo.get!(Address, address_hash)

      assert Chain.address_to_transaction_count(address) == 2
    end
  end

  describe "address_to_transactions/2" do
    test "without transactions" do
      address = insert(:address)

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      assert %Scrivener.Page{
               entries: [],
               page_number: 1,
               total_entries: 0
             } = Chain.address_to_transactions(address)
    end

    test "with from transactions" do
      %Transaction{from_address_hash: from_address_hash, hash: transaction_hash} = insert(:transaction)
      address = Repo.get!(Address, from_address_hash)

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^transaction_hash}],
               page_number: 1,
               total_entries: 1
             } = Chain.address_to_transactions(address, direction: :from)
    end

    test "with to transactions" do
      %Transaction{to_address_hash: to_address_hash, hash: transaction_hash} = insert(:transaction)
      address = Repo.get!(Address, to_address_hash)

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^transaction_hash}],
               page_number: 1,
               total_entries: 1
             } = Chain.address_to_transactions(address, direction: :to)
    end

    test "with to and from transactions and direction: :from" do
      %Transaction{from_address_hash: address_hash, hash: from_transaction_hash} = insert(:transaction)
      %Transaction{} = insert(:transaction, to_address_hash: address_hash)
      address = Repo.get!(Address, address_hash)

      # only contains "from" transaction
      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^from_transaction_hash}],
               page_number: 1,
               total_entries: 1
             } = Chain.address_to_transactions(address, direction: :from)
    end

    test "with to and from transactions and direction: :to" do
      %Transaction{from_address_hash: address_hash} = insert(:transaction)
      %Transaction{hash: to_transaction_hash} = insert(:transaction, to_address_hash: address_hash)
      address = Repo.get!(Address, address_hash)

      # only contains "to" transaction
      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^to_transaction_hash}],
               page_number: 1,
               total_entries: 1
             } = Chain.address_to_transactions(address, direction: :to)
    end

    test "with to and from transactions and no :direction option" do
      %Transaction{from_address_hash: address_hash, hash: from_transaction_hash} = insert(:transaction)
      %Transaction{hash: to_transaction_hash} = insert(:transaction, to_address_hash: address_hash)
      address = Repo.get!(Address, address_hash)

      assert %Scrivener.Page{
               entries: [
                 %Transaction{hash: ^to_transaction_hash},
                 %Transaction{hash: ^from_transaction_hash}
               ],
               page_number: 1,
               total_entries: 2
             } = Chain.address_to_transactions(address)
    end

    test "with transactions can be paginated" do
      adddress = %Address{hash: to_address_hash} = insert(:address)
      transactions = insert_list(2, :transaction, to_address_hash: to_address_hash)

      [%Transaction{hash: oldest_transaction_hash}, %Transaction{hash: newest_transaction_hash}] = transactions

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^newest_transaction_hash}],
               page_number: 1,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.address_to_transactions(adddress, pagination: %{page_size: 1})

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^oldest_transaction_hash}],
               page_number: 2,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.address_to_transactions(adddress, pagination: %{page: 2, page_size: 1})
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

  describe "block_to_transactions/1" do
    test "without transactions" do
      block = insert(:block)

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      assert %Scrivener.Page{
               entries: [],
               page_number: 1,
               total_entries: 0
             } = Chain.block_to_transactions(block)
    end

    test "with transactions" do
      %Transaction{block: block, hash: transaction_hash} =
        :transaction
        |> insert()
        |> with_block()

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^transaction_hash}],
               page_number: 1,
               total_entries: 1
             } = Chain.block_to_transactions(block)
    end

    test "with transactions can be paginated" do
      block = insert(:block)

      transactions =
        Enum.map(0..1, fn _ ->
          :transaction
          |> insert()
          |> with_block(block)
        end)

      [%Transaction{hash: first_transaction_hash}, %Transaction{hash: second_transaction_hash}] = transactions

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^second_transaction_hash}],
               page_number: 1,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.block_to_transactions(block, pagination: %{page_size: 1})

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^first_transaction_hash}],
               page_number: 2,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.block_to_transactions(block, pagination: %{page: 2, page_size: 1})
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
  end

  describe "list_blocks/2" do
    test "without blocks" do
      assert %Scrivener.Page{
               entries: [],
               page_number: 1,
               total_entries: 0,
               total_pages: 1
             } = Chain.list_blocks()
    end

    test "with blocks" do
      %Block{hash: hash} = insert(:block)

      assert %Scrivener.Page{
               entries: [%Block{hash: ^hash}],
               page_number: 1,
               total_entries: 1
             } = Chain.list_blocks()
    end

    test "with blocks can be paginated" do
      blocks = insert_list(2, :block)

      [%Block{number: lesser_block_number}, %Block{number: greater_block_number}] = blocks

      assert %Scrivener.Page{
               entries: [%Block{number: ^greater_block_number}],
               page_number: 1,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.list_blocks(pagination: %{page_size: 1})

      assert %Scrivener.Page{
               entries: [%Block{number: ^lesser_block_number}],
               page_number: 2,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.list_blocks(pagination: %{page: 2, page_size: 1})
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
        insert(:internal_transaction, index: 0, transaction_hash: transaction.hash, to_address_hash: address.hash)

      %InternalTransaction{id: second_id} =
        insert(:internal_transaction, index: 1, transaction_hash: transaction.hash, to_address_hash: address.hash)

      result = address |> Chain.address_to_internal_transactions() |> Enum.map(& &1.id)
      assert Enum.member?(result, first_id)
      assert Enum.member?(result, second_id)
    end

    test "loads associations in necessity_by_association" do
      address = insert(:address)
      transaction = insert(:transaction, to_address_hash: address.hash)
      insert(:internal_transaction, transaction_hash: transaction.hash, to_address_hash: address.hash, index: 0)
      insert(:internal_transaction, transaction_hash: transaction.hash, to_address_hash: address.hash, index: 1)

      assert [
               %InternalTransaction{
                 from_address: %Ecto.Association.NotLoaded{},
                 to_address: %Ecto.Association.NotLoaded{},
                 transaction: %Transaction{}
               }
               | _
             ] = Map.get(Chain.address_to_internal_transactions(address), :entries, [])

      assert [
               %InternalTransaction{
                 from_address: %Address{},
                 to_address: %Address{},
                 transaction: %Transaction{}
               }
               | _
             ] =
               Map.get(
                 Chain.address_to_internal_transactions(
                   address,
                   necessity_by_association: %{
                     from_address: :optional,
                     to_address: :optional,
                     transaction: :optional
                   }
                 ),
                 :entries,
                 []
               )
    end

    test "returns results in reverse chronological order by block number, transaction index, internal transaction index" do
      address = insert(:address)

      pending_transaction = insert(:transaction)

      %InternalTransaction{id: first_pending} =
        insert(
          :internal_transaction,
          transaction_hash: pending_transaction.hash,
          to_address_hash: address.hash,
          index: 0
        )

      %InternalTransaction{id: second_pending} =
        insert(
          :internal_transaction,
          transaction_hash: pending_transaction.hash,
          to_address_hash: address.hash,
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
          transaction_hash: first_a_transaction.hash,
          to_address_hash: address.hash,
          index: 0
        )

      %InternalTransaction{id: second} =
        insert(
          :internal_transaction,
          transaction_hash: first_a_transaction.hash,
          to_address_hash: address.hash,
          index: 1
        )

      second_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{id: third} =
        insert(
          :internal_transaction,
          transaction_hash: second_a_transaction.hash,
          to_address_hash: address.hash,
          index: 0
        )

      %InternalTransaction{id: fourth} =
        insert(
          :internal_transaction,
          transaction_hash: second_a_transaction.hash,
          to_address_hash: address.hash,
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
          transaction_hash: first_b_transaction.hash,
          to_address_hash: address.hash,
          index: 0
        )

      %InternalTransaction{id: sixth} =
        insert(
          :internal_transaction,
          transaction_hash: first_b_transaction.hash,
          to_address_hash: address.hash,
          index: 1
        )

      result =
        address
        |> Chain.address_to_internal_transactions()
        |> Map.get(:entries, [])
        |> Enum.map(& &1.id)

      assert [second_pending, first_pending, sixth, fifth, fourth, third, second, first] == result
    end

    test "excludes internal transactions of type `call` when they are alone in the parent transaction" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address_hash: address.hash)
        |> with_block()

      insert(:internal_transaction_call, index: 0, to_address_hash: address.hash, transaction_hash: transaction.hash)

      assert Enum.empty?(Chain.address_to_internal_transactions(address))
    end

    test "includes internal transactions of type `create` even when they are alone in the parent transaction" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address_hash: address.hash)
        |> with_block()

      expected =
        insert(
          :internal_transaction_create,
          index: 0,
          from_address_hash: address.hash,
          transaction_hash: transaction.hash
        )

      actual = Enum.at(Chain.address_to_internal_transactions(address), 0)

      assert actual.id == expected.id
    end
  end

  describe "transaction_hash_to_internal_transactions/1" do
    test "without transaction" do
      {:ok, hash} =
        Chain.string_to_transaction_hash("0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b")

      assert Chain.transaction_hash_to_internal_transactions(hash).entries == []
    end

    test "with transaction without internal transactions" do
      %Transaction{hash: hash} = insert(:transaction)

      assert Chain.transaction_hash_to_internal_transactions(hash).entries == []
    end

    test "with transaction with internal transactions returns all internal transactions for a given transaction hash" do
      transaction = insert(:transaction)
      first = insert(:internal_transaction, transaction_hash: transaction.hash, index: 0)
      second = insert(:internal_transaction, transaction_hash: transaction.hash, index: 1)

      results =
        transaction.hash
        |> Chain.transaction_hash_to_internal_transactions()
        |> Map.get(:entries, [])
        |> Enum.map(& &1.id)

      assert 2 == length(results)
      assert Enum.member?(results, first.id)
      assert Enum.member?(results, second.id)
    end

    test "with transaction with internal transactions loads associations with in necessity_by_association" do
      %Transaction{hash: hash} = insert(:transaction)
      insert(:internal_transaction_create, transaction_hash: hash, index: 0)

      assert [
               %InternalTransaction{
                 from_address: %Ecto.Association.NotLoaded{},
                 to_address: %Ecto.Association.NotLoaded{},
                 transaction: %Ecto.Association.NotLoaded{}
               }
             ] = Chain.transaction_hash_to_internal_transactions(hash).entries

      assert [
               %InternalTransaction{
                 from_address: %Address{},
                 to_address: nil,
                 transaction: %Transaction{}
               }
             ] =
               Chain.transaction_hash_to_internal_transactions(
                 hash,
                 necessity_by_association: %{
                   from_address: :optional,
                   to_address: :optional,
                   transaction: :optional
                 }
               ).entries
    end

    test "excludes internal transaction of type call with no siblings in the transaction" do
      %Transaction{hash: hash} =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction_call, transaction_hash: hash, index: 0)

      result = Chain.transaction_hash_to_internal_transactions(hash)

      assert Enum.empty?(result)
    end

    test "includes internal transactions of type `create` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected = insert(:internal_transaction_create, index: 0, transaction_hash: transaction.hash)

      actual = Enum.at(Chain.transaction_hash_to_internal_transactions(transaction.hash), 0)

      assert actual.id == expected.id
    end

    test "returns the internal transactions in index order" do
      %Transaction{hash: hash} =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{id: first_id} = insert(:internal_transaction, transaction_hash: hash, index: 0)
      %InternalTransaction{id: second_id} = insert(:internal_transaction, transaction_hash: hash, index: 1)

      result =
        hash
        |> Chain.transaction_hash_to_internal_transactions()
        |> Enum.map(& &1.id)

      assert [first_id, second_id] == result
    end
  end

  describe "transaction_to_logs/2" do
    test "without logs" do
      transaction = insert(:transaction)

      assert %Scrivener.Page{
               entries: [],
               page_number: 1,
               total_entries: 0,
               total_pages: 1
             } = Chain.transaction_to_logs(transaction)
    end

    test "with logs" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %Log{id: id} = insert(:log, transaction_hash: transaction.hash)

      assert %Scrivener.Page{
               entries: [%Log{id: ^id}],
               page_number: 1,
               total_entries: 1,
               total_pages: 1
             } = Chain.transaction_to_logs(transaction)
    end

    test "with logs can be paginated" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      logs = Enum.map(0..1, &insert(:log, index: &1, transaction_hash: transaction.hash))

      [%Log{id: first_log_id}, %Log{id: second_log_id}] = logs

      assert %Scrivener.Page{
               entries: [%Log{id: ^first_log_id}],
               page_number: 1,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.transaction_to_logs(transaction, pagination: %{page_size: 1})

      assert %Scrivener.Page{
               entries: [%Log{id: ^second_log_id}],
               page_number: 2,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.transaction_to_logs(transaction, pagination: %{page: 2, page_size: 1})
    end

    test "with logs necessity_by_association loads associations" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:log, transaction_hash: transaction.hash)

      assert %Scrivener.Page{
               entries: [
                 %Log{
                   address: %Address{},
                   transaction: %Transaction{}
                 }
               ],
               page_number: 1,
               total_entries: 1,
               total_pages: 1
             } =
               Chain.transaction_to_logs(
                 transaction,
                 necessity_by_association: %{
                   address: :optional,
                   transaction: :optional
                 }
               )

      assert %Scrivener.Page{
               entries: [
                 %Log{
                   address: %Ecto.Association.NotLoaded{},
                   transaction: %Ecto.Association.NotLoaded{}
                 }
               ],
               page_number: 1,
               total_entries: 1,
               total_pages: 1
             } = Chain.transaction_to_logs(transaction)
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
      address = insert(:address, contract_code: Factory.data("contract_code"), smart_contract: nil)

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

      insert(
        :internal_transaction,
        index: 0,
        created_contract_address_hash: created_contract_address.hash,
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

      insert(
        :internal_transaction,
        index: 0,
        created_contract_address_hash: created_contract_address.hash,
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
end
