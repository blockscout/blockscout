defmodule Explorer.ChainTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Block, InternalTransaction, Log, Receipt, Transaction}

  doctest Explorer.Chain

  # Tests

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
      block = insert(:block)
      %Transaction{hash: transaction_hash} = insert(:transaction, block_hash: block.hash)

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^transaction_hash}],
               page_number: 1,
               total_entries: 1
             } = Chain.block_to_transactions(block)
    end

    test "with transaction with receipt required without receipt does not return transaction" do
      block = %Block{hash: block_hash} = insert(:block)

      %Transaction{hash: transaction_hash_with_receipt} = insert(:transaction, block_hash: block_hash)
      insert(:receipt, transaction_hash: transaction_hash_with_receipt)

      %Transaction{hash: transaction_hash_without_receipt} = insert(:transaction, block_hash: block_hash)

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^transaction_hash_with_receipt, receipt: %Receipt{}}],
               page_number: 1,
               total_entries: 1
             } =
               Chain.block_to_transactions(
                 block,
                 necessity_by_association: %{receipt: :required}
               )

      assert %Scrivener.Page{
               entries: transactions,
               page_number: 1,
               total_entries: 2
             } =
               Chain.block_to_transactions(
                 block,
                 necessity_by_association: %{receipt: :optional}
               )

      assert length(transactions) == 2

      transaction_by_hash =
        Enum.into(transactions, %{}, fn transaction = %Transaction{hash: hash} ->
          {hash, transaction}
        end)

      assert %Transaction{receipt: %Receipt{}} = transaction_by_hash[transaction_hash_with_receipt]
      assert %Transaction{receipt: nil} = transaction_by_hash[transaction_hash_without_receipt]
    end

    test "with transactions can be paginated" do
      block = insert(:block)

      transactions = insert_list(2, :transaction, block_hash: block.hash)

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

  describe "block_to_transaction_bound/1" do
    test "without transactions" do
      block = insert(:block)

      assert Chain.block_to_transaction_count(block) == 0
    end

    test "with transactions" do
      block = insert(:block)
      insert(:transaction, block_hash: block.hash)

      assert Chain.block_to_transaction_count(block) == 1
    end
  end

  describe "confirmations/1" do
    test "with block.number == max_block_number " do
      block = insert(:block)
      max_block_number = Chain.max_block_number()

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

  describe "gas_price/2" do
    test ":wei unit" do
      assert Chain.gas_price(%Transaction{gas_price: Decimal.new(1)}, :wei) == Decimal.new(1)
    end

    test ":gwei unit" do
      assert Chain.gas_price(%Transaction{gas_price: Decimal.new(1)}, :gwei) == Decimal.new("1e-9")

      assert Chain.gas_price(%Transaction{gas_price: Decimal.new("1e9")}, :gwei) == Decimal.new(1)
    end

    test ":ether unit" do
      assert Chain.gas_price(%Transaction{gas_price: Decimal.new(1)}, :ether) == Decimal.new("1e-18")

      assert Chain.gas_price(%Transaction{gas_price: Decimal.new("1e18")}, :ether) == Decimal.new(1)
    end
  end

  describe "from_address_to_transactions/2" do
    test "without transactions" do
      address = insert(:address)

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      assert %Scrivener.Page{
               entries: [],
               page_number: 1,
               total_entries: 0
             } = Chain.from_address_to_transactions(address)
    end

    test "with transactions" do
      %Transaction{from_address_hash: from_address_hash, hash: transaction_hash} = insert(:transaction)
      address = Repo.get!(Address, from_address_hash)

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^transaction_hash}],
               page_number: 1,
               total_entries: 1
             } = Chain.from_address_to_transactions(address)
    end

    test "with transactions with receipt required without receipt does not return transaction" do
      address = %Address{hash: from_address_hash} = insert(:address)

      %Transaction{hash: transaction_hash_with_receipt} = insert(:transaction, from_address_hash: from_address_hash)

      insert(:receipt, transaction_hash: transaction_hash_with_receipt)

      %Transaction{hash: transaction_hash_without_receipt} = insert(:transaction, from_address_hash: from_address_hash)

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^transaction_hash_with_receipt, receipt: %Receipt{}}],
               page_number: 1,
               total_entries: 1
             } =
               Chain.from_address_to_transactions(
                 address,
                 necessity_by_association: %{receipt: :required}
               )

      assert %Scrivener.Page{
               entries: transactions,
               page_number: 1,
               total_entries: 2
             } =
               Chain.from_address_to_transactions(
                 address,
                 necessity_by_association: %{receipt: :optional}
               )

      assert length(transactions) == 2

      transaction_by_hash =
        Enum.into(transactions, %{}, fn transaction = %Transaction{hash: hash} ->
          {hash, transaction}
        end)

      assert %Transaction{receipt: %Receipt{}} = transaction_by_hash[transaction_hash_with_receipt]
      assert %Transaction{receipt: nil} = transaction_by_hash[transaction_hash_without_receipt]
    end

    test "with transactions can be paginated" do
      adddress = %Address{hash: from_address_hash} = insert(:address)
      transactions = insert_list(2, :transaction, from_address_hash: from_address_hash)

      [%Transaction{hash: oldest_transaction_hash}, %Transaction{hash: newest_transaction_hash}] = transactions

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^newest_transaction_hash}],
               page_number: 1,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.from_address_to_transactions(adddress, pagination: %{page_size: 1})

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^oldest_transaction_hash}],
               page_number: 2,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.from_address_to_transactions(adddress, pagination: %{page: 2, page_size: 1})
    end
  end

  describe "hash_to_transaction/2" do
    test "with transaction with receipt required without receipt returns {:error, :not_found}" do
      %Transaction{hash: hash_with_receipt} = insert(:transaction)

      insert(:receipt, transaction_hash: hash_with_receipt)

      %Transaction{hash: hash_without_receipt} = insert(:transaction)

      assert {:ok, %Transaction{hash: ^hash_with_receipt}} =
               Chain.hash_to_transaction(
                 hash_with_receipt,
                 necessity_by_association: %{receipt: :required}
               )

      assert {:error, :not_found} =
               Chain.hash_to_transaction(
                 hash_without_receipt,
                 necessity_by_association: %{receipt: :required}
               )

      assert {:ok, %Transaction{hash: ^hash_without_receipt}} =
               Chain.hash_to_transaction(
                 hash_without_receipt,
                 necessity_by_association: %{receipt: :optional}
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

  describe "max_block_number/0" do
    test "without blocks is nil" do
      assert Chain.max_block_number() == nil
    end

    test "with blocks is max number regardless of insertion order" do
      max_number = 2
      insert(:block, number: max_number)

      insert(:block, number: 1)

      assert Chain.max_block_number() == max_number
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

  describe "to_address_to_transactions/2" do
    test "without transactions" do
      address = insert(:address)

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      assert %Scrivener.Page{
               entries: [],
               page_number: 1,
               total_entries: 0
             } = Chain.to_address_to_transactions(address)
    end

    test "with transactions" do
      %Transaction{to_address_hash: to_address_hash, hash: transaction_hash} = insert(:transaction)
      address = Repo.get!(Address, to_address_hash)

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^transaction_hash}],
               page_number: 1,
               total_entries: 1
             } = Chain.to_address_to_transactions(address)
    end

    test "with transactions with receipt required without receipt does not return transaction" do
      address = %Address{hash: to_address_hash} = insert(:address)

      %Transaction{hash: transaction_hash_with_receipt} = insert(:transaction, to_address_hash: to_address_hash)

      insert(:receipt, transaction_hash: transaction_hash_with_receipt)

      %Transaction{hash: transaction_hash_without_receipt} = insert(:transaction, to_address_hash: to_address_hash)

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^transaction_hash_with_receipt, receipt: %Receipt{}}],
               page_number: 1,
               total_entries: 1
             } =
               Chain.to_address_to_transactions(
                 address,
                 necessity_by_association: %{receipt: :required}
               )

      assert %Scrivener.Page{
               entries: transactions,
               page_number: 1,
               total_entries: 2
             } =
               Chain.to_address_to_transactions(
                 address,
                 necessity_by_association: %{receipt: :optional}
               )

      assert length(transactions) == 2

      transaction_by_hash =
        Enum.into(transactions, %{}, fn transaction = %Transaction{hash: hash} ->
          {hash, transaction}
        end)

      assert %Transaction{receipt: %Receipt{}} = transaction_by_hash[transaction_hash_with_receipt]
      assert %Transaction{receipt: nil} = transaction_by_hash[transaction_hash_without_receipt]
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
             } = Chain.to_address_to_transactions(adddress, pagination: %{page_size: 1})

      assert %Scrivener.Page{
               entries: [%Transaction{hash: ^oldest_transaction_hash}],
               page_number: 2,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.to_address_to_transactions(adddress, pagination: %{page: 2, page_size: 1})
    end
  end

  describe "transaction_hash_to_internal_transactions/1" do
    test "without transaction" do
      {:ok, hash} =
        Chain.string_to_transaction_hash("0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b")

      assert Chain.transaction_hash_to_internal_transactions(hash) == []
    end

    test "with transaction without internal transactions" do
      %Transaction{hash: hash} = insert(:transaction)

      assert Chain.transaction_hash_to_internal_transactions(hash) == []
    end

    test "with transaction with internal transactions returns all internal transactions for a given transaction hash" do
      transaction = insert(:transaction)
      internal_transaction = insert(:internal_transaction, transaction_hash: transaction.hash)

      result = hd(Chain.transaction_hash_to_internal_transactions(transaction.hash))

      assert result.id == internal_transaction.id
    end

    test "with transaction with internal transactions loads associations with in necessity_by_assocation" do
      %Transaction{hash: hash} = insert(:transaction)
      insert(:internal_transaction, transaction_hash: hash)

      assert [
               %InternalTransaction{
                 from_address: %Ecto.Association.NotLoaded{},
                 to_address: %Ecto.Association.NotLoaded{},
                 transaction: %Ecto.Association.NotLoaded{}
               }
             ] = Chain.transaction_hash_to_internal_transactions(hash)

      assert [
               %InternalTransaction{
                 from_address: %Address{},
                 to_address: %Address{},
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
               )
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
      transaction = insert(:transaction)
      %Receipt{id: receipt_id} = insert(:receipt, transaction_hash: transaction.hash)
      %Log{id: id} = insert(:log, receipt_id: receipt_id)

      assert %Scrivener.Page{
               entries: [%Log{id: ^id}],
               page_number: 1,
               total_entries: 1,
               total_pages: 1
             } = Chain.transaction_to_logs(transaction)
    end

    test "with logs can be paginated" do
      transaction = insert(:transaction)
      %Receipt{id: receipt_id} = insert(:receipt, transaction_hash: transaction.hash)
      logs = insert_list(2, :log, receipt_id: receipt_id)

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
      transaction = insert(:transaction)
      %Receipt{id: receipt_id} = insert(:receipt, transaction_hash: transaction.hash)
      insert(:log, receipt_id: receipt_id)

      assert %Scrivener.Page{
               entries: [
                 %Log{
                   address: %Address{},
                   receipt: %Receipt{},
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
                   receipt: :optional,
                   transaction: :optional
                 }
               )

      assert %Scrivener.Page{
               entries: [
                 %Log{
                   address: %Ecto.Association.NotLoaded{},
                   receipt: %Ecto.Association.NotLoaded{},
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
      assert Chain.value(%InternalTransaction{value: Decimal.new(1)}, :wei) == Decimal.new(1)
    end

    test "with InternalTransaction.t with :gwei" do
      assert Chain.value(%InternalTransaction{value: Decimal.new(1)}, :gwei) == Decimal.new("1e-9")

      assert Chain.value(%InternalTransaction{value: Decimal.new("1e9")}, :gwei) == Decimal.new(1)
    end

    test "with InternalTransaction.t with :ether" do
      assert Chain.value(%InternalTransaction{value: Decimal.new(1)}, :ether) == Decimal.new("1e-18")

      assert Chain.value(%InternalTransaction{value: Decimal.new("1e18")}, :ether) == Decimal.new(1)
    end

    test "with Transaction.t with :wei" do
      assert Chain.value(%Transaction{value: Decimal.new(1)}, :wei) == Decimal.new(1)
    end

    test "with Transaction.t with :gwei" do
      assert Chain.value(%Transaction{value: Decimal.new(1)}, :gwei) == Decimal.new("1e-9")
      assert Chain.value(%Transaction{value: Decimal.new("1e9")}, :gwei) == Decimal.new(1)
    end

    test "with Transaction.t with :ether" do
      assert Chain.value(%Transaction{value: Decimal.new(1)}, :ether) == Decimal.new("1e-18")
      assert Chain.value(%Transaction{value: Decimal.new("1e18")}, :ether) == Decimal.new(1)
    end
  end
end
