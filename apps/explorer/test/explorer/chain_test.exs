defmodule Explorer.ChainTest do
  use Explorer.DataCase

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.{Address, Block, InternalTransaction, Log, Receipt, Transaction}

  # Constants

  @invalid_attrs %{hash: nil}
  @valid_attrs %{hash: "some hash"}

  # Tests

  describe "block_to_transactions/1" do
    test "without transactions" do
      block = insert(:block)

      assert Repo.aggregate(Transaction, :count, :id) == 0

      assert %Scrivener.Page{
               entries: [],
               page_number: 1,
               total_entries: 0
             } = Chain.block_to_transactions(block)
    end

    test "with transactions" do
      block = %Block{id: block_id} = insert(:block)
      %Transaction{id: transaction_id} = insert(:transaction)
      insert(:block_transaction, block_id: block_id, transaction_id: transaction_id)

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^transaction_id}],
               page_number: 1,
               total_entries: 1
             } = Chain.block_to_transactions(block)
    end

    test "with transaction with receipt required without receipt does not return transaction" do
      block = %Block{id: block_id} = insert(:block)

      %Transaction{id: transaction_id_with_receipt} = insert(:transaction)
      insert(:receipt, transaction_id: transaction_id_with_receipt)
      insert(:block_transaction, block_id: block_id, transaction_id: transaction_id_with_receipt)

      %Transaction{id: transaction_id_without_receipt} = insert(:transaction)

      insert(
        :block_transaction,
        block_id: block_id,
        transaction_id: transaction_id_without_receipt
      )

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^transaction_id_with_receipt, receipt: %Receipt{}}],
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

      transaction_by_id =
        Enum.into(transactions, %{}, fn transaction = %Transaction{id: id} ->
          {id, transaction}
        end)

      assert %Transaction{receipt: %Receipt{}} = transaction_by_id[transaction_id_with_receipt]
      assert %Transaction{receipt: nil} = transaction_by_id[transaction_id_without_receipt]
    end

    test "with transactions can be paginated" do
      block = %Block{id: block_id} = insert(:block)

      transactions = insert_list(2, :transaction)

      Enum.each(transactions, fn %Transaction{id: transaction_id} ->
        insert(:block_transaction, block_id: block_id, transaction_id: transaction_id)
      end)

      [%Transaction{id: first_transaction_id}, %Transaction{id: second_transaction_id}] =
        transactions

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^first_transaction_id}],
               page_number: 1,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.block_to_transactions(block, pagination: %{page_size: 1})

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^second_transaction_id}],
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
      %Transaction{id: transaction_id} = insert(:transaction)
      insert(:block_transaction, block_id: block.id, transaction_id: transaction_id)

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

      assert Chain.confirmations(block, max_block_number: max_block_number) ==
               max_block_number - block.number
    end
  end

  describe "create_address/1" do
    test "with valid data creates a address" do
      assert {:ok, %Address{} = address} = Chain.create_address(@valid_attrs)
      assert address.hash == "some hash"
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chain.create_address(@invalid_attrs)
    end
  end

  describe "ensure_hash_address/1" do
    test "creates a new address when one does not exist" do
      Chain.ensure_hash_address("0xFreshPrince")

      assert {:ok, _} = Chain.hash_to_address("0xfreshprince")
    end

    test "when the address already exists doesn't insert a new address" do
      insert(:address, %{hash: "bigmouthbillybass"})

      before = Repo.aggregate(Address, :count, :id)

      assert {:ok, _} = Chain.ensure_hash_address("bigmouthbillybass")

      assert Repo.aggregate(Address, :count, :id) == before
    end

    test "when there is no hash it blows up" do
      assert {:error, :not_found} = Chain.ensure_hash_address("")
    end
  end

  describe "from_address_to_transactions/2" do
    test "without transactions" do
      address = insert(:address)

      assert Repo.aggregate(Transaction, :count, :id) == 0

      assert %Scrivener.Page{
               entries: [],
               page_number: 1,
               total_entries: 0
             } = Chain.from_address_to_transactions(address)
    end

    test "with transactions" do
      %Transaction{from_address_id: from_address_id, id: transaction_id} = insert(:transaction)
      address = Repo.get!(Address, from_address_id)

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^transaction_id}],
               page_number: 1,
               total_entries: 1
             } = Chain.from_address_to_transactions(address)
    end

    test "with transactions with receipt required without receipt does not return transaction" do
      address = %Address{id: from_address_id} = insert(:address)

      %Transaction{id: transaction_id_with_receipt} =
        insert(:transaction, from_address_id: from_address_id)

      insert(:receipt, transaction_id: transaction_id_with_receipt)

      %Transaction{id: transaction_id_without_receipt} =
        insert(:transaction, from_address_id: from_address_id)

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^transaction_id_with_receipt, receipt: %Receipt{}}],
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

      transaction_by_id =
        Enum.into(transactions, %{}, fn transaction = %Transaction{id: id} ->
          {id, transaction}
        end)

      assert %Transaction{receipt: %Receipt{}} = transaction_by_id[transaction_id_with_receipt]
      assert %Transaction{receipt: nil} = transaction_by_id[transaction_id_without_receipt]
    end

    test "with transactions can be paginated" do
      adddress = %Address{id: from_address_id} = insert(:address)
      transactions = insert_list(2, :transaction, from_address_id: from_address_id)

      [%Transaction{id: oldest_transaction_id}, %Transaction{id: newest_transaction_id}] =
        transactions

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^newest_transaction_id}],
               page_number: 1,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.from_address_to_transactions(adddress, pagination: %{page_size: 1})

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^oldest_transaction_id}],
               page_number: 2,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } =
               Chain.from_address_to_transactions(adddress, pagination: %{page: 2, page_size: 1})
    end
  end

  describe "hash_to_address/1" do
    test "without address returns {:error, :not_found}" do
      assert {:error, :not_found} = Chain.hash_to_address("unknown")
    end

    test "with address returns {:ok, address}" do
      hash = "0xandesmints"
      %Address{id: address_id} = insert(:address, hash: hash)

      assert {:ok, %Address{id: ^address_id}} = Chain.hash_to_address(hash)
    end
  end

  describe "hash_to_transaction/2" do
    test "without transaction returns {:error, :not_found}" do
      assert {:error, :not_found} = Chain.hash_to_transaction("unknown")
    end

    test "with transaction returns {:ok, transaction}" do
      hash = "0xandesmints"
      %Transaction{id: transaction_id} = insert(:transaction, hash: hash)

      assert {:ok, %Transaction{id: ^transaction_id}} = Chain.hash_to_transaction(hash)
    end

    test "with transaction with receipt required without receipt returns {:error, :not_found}" do
      %Transaction{hash: hash_with_receipt, id: transaction_id_with_receipt} =
        insert(:transaction)

      insert(:receipt, transaction_id: transaction_id_with_receipt)

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

  describe "id_to_address/1" do
    test "returns the address with given id" do
      %Address{id: id} = insert(:address)

      assert {:ok, %Address{id: ^id}} = Chain.id_to_address(id)
    end
  end

  describe "last_transaction_id/1" do
    test "without transactions returns 0" do
      assert Chain.last_transaction_id() == 0
    end

    test "with transaction returns last created transaction's id" do
      insert(:transaction)
      %Transaction{id: id} = insert(:transaction)

      assert Chain.last_transaction_id() == id
    end

    test "with transaction with pending: true returns last pending transaction id, not the last transaction" do
      %Transaction{id: pending_transaction_id} = insert(:transaction)

      %Transaction{id: transaction_id} = insert(:transaction)
      insert(:receipt, transaction_id: transaction_id)

      assert pending_transaction_id < transaction_id

      assert Chain.last_transaction_id(pending: true) == pending_transaction_id
      assert Chain.last_transaction_id(pending: false) == transaction_id
      assert Chain.last_transaction_id() == transaction_id
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
      %Block{id: id} = insert(:block)

      assert %Scrivener.Page{
               entries: [%Block{id: ^id}],
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

      assert Repo.aggregate(Transaction, :count, :id) == 0

      assert %Scrivener.Page{
               entries: [],
               page_number: 1,
               total_entries: 0
             } = Chain.to_address_to_transactions(address)
    end

    test "with transactions" do
      %Transaction{to_address_id: to_address_id, id: transaction_id} = insert(:transaction)
      address = Repo.get!(Address, to_address_id)

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^transaction_id}],
               page_number: 1,
               total_entries: 1
             } = Chain.to_address_to_transactions(address)
    end

    test "with transactions with receipt required without receipt does not return transaction" do
      address = %Address{id: to_address_id} = insert(:address)

      %Transaction{id: transaction_id_with_receipt} =
        insert(:transaction, to_address_id: to_address_id)

      insert(:receipt, transaction_id: transaction_id_with_receipt)

      %Transaction{id: transaction_id_without_receipt} =
        insert(:transaction, to_address_id: to_address_id)

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^transaction_id_with_receipt, receipt: %Receipt{}}],
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

      transaction_by_id =
        Enum.into(transactions, %{}, fn transaction = %Transaction{id: id} ->
          {id, transaction}
        end)

      assert %Transaction{receipt: %Receipt{}} = transaction_by_id[transaction_id_with_receipt]
      assert %Transaction{receipt: nil} = transaction_by_id[transaction_id_without_receipt]
    end

    test "with transactions can be paginated" do
      adddress = %Address{id: to_address_id} = insert(:address)
      transactions = insert_list(2, :transaction, to_address_id: to_address_id)

      [%Transaction{id: oldest_transaction_id}, %Transaction{id: newest_transaction_id}] =
        transactions

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^newest_transaction_id}],
               page_number: 1,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.to_address_to_transactions(adddress, pagination: %{page_size: 1})

      assert %Scrivener.Page{
               entries: [%Transaction{id: ^oldest_transaction_id}],
               page_number: 2,
               page_size: 1,
               total_entries: 2,
               total_pages: 2
             } = Chain.to_address_to_transactions(adddress, pagination: %{page: 2, page_size: 1})
    end
  end

  describe "transaction_count/0" do
    test "without transactions" do
      assert Chain.transaction_count() == 0
    end

    test "with transactions" do
      count = 2
      insert_list(count, :transaction)

      assert Chain.transaction_count() == count
    end

    test "with transaction pending: true counts only pending transactions" do
      insert(:transaction)

      %Transaction{id: transaction_id} = insert(:transaction)
      insert(:receipt, transaction_id: transaction_id)

      assert Chain.transaction_count(pending: true) == 1
      assert Chain.transaction_count(pending: false) == 2
      assert Chain.transaction_count() == 2
    end
  end

  describe "transaction_hash_to_internal_transactions/1" do
    test "without transaction" do
      assert Chain.transaction_hash_to_internal_transactions("unknown") == []
    end

    test "with transaction without internal transactions" do
      %Transaction{hash: hash} = insert(:transaction)

      assert Chain.transaction_hash_to_internal_transactions(hash) == []
    end

    test "with transaction with internal transactions returns all internal transactions for a given transaction hash" do
      transaction = insert(:transaction)
      internal_transaction = insert(:internal_transaction, transaction_id: transaction.id)

      result = hd(Chain.transaction_hash_to_internal_transactions(transaction.hash))

      assert result.id == internal_transaction.id
    end

    test "with transaction with internal transactions loads associations with in necessity_by_assocation" do
      %Transaction{hash: hash, id: transaction_id} = insert(:transaction)
      insert(:internal_transaction, transaction_id: transaction_id)

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

  describe "transactions_recently_before_id" do
    test "returns at most 10 transactions" do
      count = 12

      assert 10 < count

      transactions = insert_list(count, :transaction)
      %Transaction{id: last_transaction_id} = List.last(transactions)

      recent_transactions = Chain.transactions_recently_before_id(last_transaction_id)

      assert length(recent_transactions) == 10
    end

    test "with pending: true returns only pending transactions" do
      count = 12

      transactions = insert_list(count, :transaction)
      %Transaction{id: last_transaction_id} = List.last(transactions)

      transactions
      |> Enum.take(3)
      |> Enum.each(fn %Transaction{id: id} ->
        insert(:receipt, transaction_id: id)
      end)

      assert length(Chain.transactions_recently_before_id(last_transaction_id, pending: true)) ==
               8

      assert length(Chain.transactions_recently_before_id(last_transaction_id, pending: false)) ==
               10

      assert length(Chain.transactions_recently_before_id(last_transaction_id)) == 10
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
      %Receipt{id: receipt_id} = insert(:receipt, transaction_id: transaction.id)
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
      %Receipt{id: receipt_id} = insert(:receipt, transaction_id: transaction.id)
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
      %Receipt{id: receipt_id} = insert(:receipt, transaction_id: transaction.id)
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

  describe "update_balance/2" do
    test "updates the balance" do
      hash = "0xwarheads"
      insert(:address, hash: hash)

      Chain.update_balance(hash, 5)

      expected_balance = Decimal.new(5)

      assert {:ok, %Address{balance: ^expected_balance}} = Chain.hash_to_address(hash)
    end

    test "updates the balance timestamp" do
      hash = "0xtwizzlers"
      insert(:address, hash: hash)

      Chain.update_balance(hash, 88)

      assert {:ok, %Address{balance_updated_at: balance_updated_at}} =
               Chain.hash_to_address("0xtwizzlers")

      refute is_nil(balance_updated_at)
    end

    test "creates an address if one does not exist" do
      Chain.update_balance("0xtwizzlers", 88)

      expected_balance = Decimal.new(88)

      assert {:ok, %Address{balance: ^expected_balance}} = Chain.hash_to_address("0xtwizzlers")
    end
  end
end
