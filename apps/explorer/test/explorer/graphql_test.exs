defmodule Explorer.GraphQLTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{GraphQL, Repo}

  describe "address_to_transactions_query/1" do
    test "with address hash with zero transactions" do
      result =
        :address
        |> insert()
        |> GraphQL.address_to_transactions_query()
        |> Repo.all()

      assert result == []
    end

    test "with matching 'to_address_hash'" do
      address = insert(:address)
      transaction = insert(:transaction, to_address: address)
      insert(:transaction)

      [found_transaction] =
        address
        |> GraphQL.address_to_transactions_query()
        |> Repo.all()

      assert found_transaction.hash == transaction.hash
    end

    test "with matching 'from_address_hash'" do
      address = insert(:address)
      transaction = insert(:transaction, from_address: address)
      insert(:transaction)

      [found_transaction] =
        address
        |> GraphQL.address_to_transactions_query()
        |> Repo.all()

      assert found_transaction.hash == transaction.hash
    end

    test "with matching 'created_contract_address_hash'" do
      address = insert(:address)
      transaction = insert(:transaction, created_contract_address: address)
      insert(:transaction)

      [found_transaction] =
        address
        |> GraphQL.address_to_transactions_query()
        |> Repo.all()

      assert found_transaction.hash == transaction.hash
    end

    test "orders by descending block and index" do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)

      address = insert(:address)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(third_block)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      found_transactions =
        address
        |> GraphQL.address_to_transactions_query()
        |> Repo.all()

      block_number_and_index_order =
        Enum.map(found_transactions, fn transaction ->
          {transaction.block_number, transaction.index}
        end)

      assert block_number_and_index_order == Enum.sort(block_number_and_index_order, &(&1 >= &2))
    end
  end
end
