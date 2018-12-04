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

  describe "get_internal_transaction/1" do
    test "returns existing internal transaction" do
      transaction = insert(:transaction)

      internal_transaction = insert(:internal_transaction, transaction: transaction, index: 0)

      clauses = %{transaction_hash: transaction.hash, index: internal_transaction.index}

      {:ok, found_internal_transaction} = GraphQL.get_internal_transaction(clauses)

      assert found_internal_transaction.transaction_hash == transaction.hash
      assert found_internal_transaction.index == internal_transaction.index
    end

    test "returns error tuple for non-existent internal transaction" do
      transaction = build(:transaction)

      internal_transaction = build(:internal_transaction, transaction: transaction, index: 0)

      clauses = %{transaction_hash: transaction.hash, index: internal_transaction.index}

      assert GraphQL.get_internal_transaction(clauses) == {:error, "Internal transaction not found."}
    end
  end

  describe "transcation_to_internal_transactions_query/1" do
    test "with transaction with one internal transaction" do
      transaction1 = insert(:transaction)
      transaction2 = insert(:transaction)

      internal_transaction = insert(:internal_transaction_create, transaction: transaction1, index: 0)
      insert(:internal_transaction_create, transaction: transaction2, index: 0)

      [found_internal_transaction] =
        transaction1
        |> GraphQL.transaction_to_internal_transactions_query()
        |> Repo.all()

      assert found_internal_transaction.transaction_hash == transaction1.hash
      assert found_internal_transaction.index == internal_transaction.index
    end

    test "with transaction with multiple internal transactions" do
      transaction1 = insert(:transaction)
      transaction2 = insert(:transaction)

      for index <- 0..2 do
        insert(:internal_transaction_create, transaction: transaction1, index: index)
      end

      insert(:internal_transaction_create, transaction: transaction2, index: 0)

      found_internal_transactions =
        transaction1
        |> GraphQL.transaction_to_internal_transactions_query()
        |> Repo.all()

      assert length(found_internal_transactions) == 3

      for found_internal_transaction <- found_internal_transactions do
        assert found_internal_transaction.transaction_hash == transaction1.hash
      end
    end

    test "orders internal transactions by ascending index" do
      transaction = insert(:transaction)

      insert(:internal_transaction_create, transaction: transaction, index: 2)
      insert(:internal_transaction_create, transaction: transaction, index: 0)
      insert(:internal_transaction_create, transaction: transaction, index: 1)

      found_internal_transactions =
        transaction
        |> GraphQL.transaction_to_internal_transactions_query()
        |> Repo.all()

      index_order = Enum.map(found_internal_transactions, & &1.index)

      assert index_order == Enum.sort(index_order)
    end

    # Note that `transaction_to_internal_transactions_query/1` relies on
    # `Explorer.Chain.where_transaction_has_multiple_transactions/1` to ensure the
    # following behavior:
    #
    # * exclude internal transactions of type call with no siblings in the
    #   transaction
    #
    # * include internal transactions of type create, reward, or suicide
    #   even when they are alone in the parent transaction
    #
    # These two requirements are tested in `Explorer.ChainTest`.
  end
end
