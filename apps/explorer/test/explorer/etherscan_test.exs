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

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      %{created_contract_address_hash: contract_address_hash} =
        insert(:internal_transaction_create, transaction: transaction, index: 0)

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

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      %{created_contract_address_hash: contract_hash} =
        insert(:internal_transaction_create, transaction: transaction, index: 0)

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

    test "orders transactions by block, in ascending order" do
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
  end
end
