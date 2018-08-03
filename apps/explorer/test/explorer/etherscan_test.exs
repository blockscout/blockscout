defmodule Explorer.EtherscanTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{Etherscan, Chain}
  alias Explorer.Chain.Transaction

  describe "list_transactions/1" do
    test "with empty db" do
      address = build(:address)

      assert Etherscan.list_transactions(address.hash) == []
    end

    test "with from address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      [found_transaction] = Etherscan.list_transactions(address.hash)

      assert transaction.hash == found_transaction.hash
    end

    test "with to address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      [found_transaction] = Etherscan.list_transactions(address.hash)

      assert transaction.hash == found_transaction.hash
    end

    test "with same to and from address" do
      address = insert(:address)

      _transaction =
        :transaction
        |> insert(from_address: address, to_address: address)
        |> with_block()

      found_transactions = Etherscan.list_transactions(address.hash)

      assert length(found_transactions) == 1
    end

    test "with created contract address" do
      address = insert(:address)
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(from_address: address, to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block()

      %{created_contract_address_hash: contract_address_hash} =
        :internal_transaction_create
        |> insert(transaction: transaction, index: 0)
        |> with_contract_creation(contract_address)

      [found_transaction] = Etherscan.list_transactions(contract_address_hash)

      assert found_transaction.hash == transaction.hash
    end

    test "with address with 0 transactions" do
      address1 = insert(:address)
      address2 = insert(:address)

      :transaction
      |> insert(from_address: address2)
      |> with_block()

      assert Etherscan.list_transactions(address1.hash) == []
    end

    test "with address with multiple transactions" do
      address1 = insert(:address)
      address2 = insert(:address)

      3
      |> insert_list(:transaction, from_address: address1)
      |> with_block()

      :transaction
      |> insert(from_address: address2)
      |> with_block()

      found_transactions = Etherscan.list_transactions(address1.hash)

      assert length(found_transactions) == 3

      for found_transaction <- found_transactions do
        assert found_transaction.from_address_hash == address1.hash
      end
    end

    test "includes confirmations value" do
      insert(:block)
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      insert(:block)

      [found_transaction] = Etherscan.list_transactions(address.hash)

      {:ok, max_block_number} = Chain.max_block_number()
      expected_confirmations = max_block_number - transaction.block_number

      assert found_transaction.confirmations == expected_confirmations
    end

    test "loads created_contract_address_hash if available" do
      address = insert(:address)
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(from_address: address, to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block()

      %{created_contract_address_hash: contract_hash} =
        :internal_transaction_create
        |> insert(transaction: transaction, index: 0)
        |> with_contract_creation(contract_address)

      [found_transaction] = Etherscan.list_transactions(address.hash)

      assert found_transaction.created_contract_address_hash == contract_hash
    end

    test "loads block_timestamp" do
      address = insert(:address)

      %Transaction{block: block} =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      [found_transaction] = Etherscan.list_transactions(address.hash)

      assert found_transaction.block_timestamp == block.timestamp
    end

    test "orders transactions by block, in ascending order (default)" do
      first_block = insert(:block)
      second_block = insert(:block)
      address = insert(:address)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block()

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      found_transactions = Etherscan.list_transactions(address.hash)

      block_numbers_order = Enum.map(found_transactions, & &1.block_number)

      assert block_numbers_order == Enum.sort(block_numbers_order)
    end

    test "orders transactions by block, in descending order" do
      first_block = insert(:block)
      second_block = insert(:block)
      address = insert(:address)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block()

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      options = %{order_by_direction: :desc}

      found_transactions = Etherscan.list_transactions(address.hash, options)

      block_numbers_order = Enum.map(found_transactions, & &1.block_number)

      assert block_numbers_order == Enum.sort(block_numbers_order, &(&1 >= &2))
    end

    test "with page_size and page_number options" do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)
      address = insert(:address)

      second_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(second_block)

      third_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(third_block)

      first_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(first_block)

      options = %{page_number: 1, page_size: 2}

      page1_transactions = Etherscan.list_transactions(address.hash, options)

      page1_hashes = Enum.map(page1_transactions, & &1.hash)

      assert length(page1_transactions) == 2

      for transaction <- first_block_transactions do
        assert transaction.hash in page1_hashes
      end

      options = %{page_number: 2, page_size: 2}

      page2_transactions = Etherscan.list_transactions(address.hash, options)

      page2_hashes = Enum.map(page2_transactions, & &1.hash)

      assert length(page2_transactions) == 2

      for transaction <- second_block_transactions do
        assert transaction.hash in page2_hashes
      end

      options = %{page_number: 3, page_size: 2}

      page3_transactions = Etherscan.list_transactions(address.hash, options)

      page3_hashes = Enum.map(page3_transactions, & &1.hash)

      assert length(page3_transactions) == 2

      for transaction <- third_block_transactions do
        assert transaction.hash in page3_hashes
      end

      options = %{page_number: 4, page_size: 2}

      assert Etherscan.list_transactions(address.hash, options) == []
    end

    test "with start and end block options" do
      blocks = [_, second_block, third_block, _] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      options = %{
        start_block: second_block.number,
        end_block: third_block.number
      }

      found_transactions = Etherscan.list_transactions(address.hash, options)

      expected_block_numbers = [second_block.number, third_block.number]

      assert length(found_transactions) == 4

      for transaction <- found_transactions do
        assert transaction.block_number in expected_block_numbers
      end
    end

    test "with start_block but no end_block option" do
      blocks = [_, _, third_block, fourth_block] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      options = %{
        start_block: third_block.number
      }

      found_transactions = Etherscan.list_transactions(address.hash, options)

      expected_block_numbers = [third_block.number, fourth_block.number]

      assert length(found_transactions) == 4

      for transaction <- found_transactions do
        assert transaction.block_number in expected_block_numbers
      end
    end

    test "with end_block but no start_block option" do
      blocks = [first_block, second_block, _, _] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      options = %{
        end_block: second_block.number
      }

      found_transactions = Etherscan.list_transactions(address.hash, options)

      expected_block_numbers = [first_block.number, second_block.number]

      assert length(found_transactions) == 4

      for transaction <- found_transactions do
        assert transaction.block_number in expected_block_numbers
      end
    end
  end
end
