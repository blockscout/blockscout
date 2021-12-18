defmodule Explorer.GraphQLTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{GraphQL, Repo}
  alias Explorer.Chain.Address

  describe "address_to_transactions_query/1" do
    test "with address hash with zero transactions" do
      result =
        :address
        |> insert()
        |> Map.get(:hash)
        |> GraphQL.address_to_transactions_query()
        |> Repo.replica().all()

      assert result == []
    end

    test "with matching 'to_address_hash'" do
      %Address{hash: address_hash} = address = insert(:address)
      transaction = insert(:transaction, to_address: address)
      insert(:transaction)

      [found_transaction] =
        address_hash
        |> GraphQL.address_to_transactions_query()
        |> Repo.replica().all()

      assert found_transaction.hash == transaction.hash
    end

    test "with matching 'from_address_hash'" do
      %Address{hash: address_hash} = address = insert(:address)
      transaction = insert(:transaction, from_address: address)
      insert(:transaction)

      [found_transaction] =
        address_hash
        |> GraphQL.address_to_transactions_query()
        |> Repo.replica().all()

      assert found_transaction.hash == transaction.hash
    end

    test "with matching 'created_contract_address_hash'" do
      %Address{hash: address_hash} = address = insert(:address)
      transaction = insert(:transaction, created_contract_address: address)
      insert(:transaction)

      [found_transaction] =
        address_hash
        |> GraphQL.address_to_transactions_query()
        |> Repo.replica().all()

      assert found_transaction.hash == transaction.hash
    end

    test "orders by descending block and index" do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)

      %Address{hash: address_hash} = address = insert(:address)

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
        address_hash
        |> GraphQL.address_to_transactions_query()
        |> Repo.replica().all()

      block_number_and_index_order =
        Enum.map(found_transactions, fn transaction ->
          {transaction.block_number, transaction.index}
        end)

      assert block_number_and_index_order == Enum.sort(block_number_and_index_order, &(&1 >= &2))
    end
  end

  describe "get_internal_transaction/1" do
    test "returns existing internal transaction" do
      transaction = insert(:transaction) |> with_block()

      internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_hash: transaction.block_hash,
          block_index: 0
        )

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
      transaction1 = insert(:transaction) |> with_block()
      transaction2 = insert(:transaction) |> with_block()

      internal_transaction =
        insert(:internal_transaction_create,
          transaction: transaction1,
          index: 0,
          block_hash: transaction1.block_hash,
          block_index: 0
        )

      insert(:internal_transaction_create,
        transaction: transaction2,
        index: 0,
        block_hash: transaction2.block_hash,
        block_index: 0
      )

      [found_internal_transaction] =
        transaction1
        |> GraphQL.transaction_to_internal_transactions_query()
        |> Repo.replica().all()

      assert found_internal_transaction.transaction_hash == transaction1.hash
      assert found_internal_transaction.index == internal_transaction.index
    end

    test "with transaction with multiple internal transactions" do
      transaction1 = insert(:transaction) |> with_block()
      transaction2 = insert(:transaction) |> with_block()

      for index <- 0..2 do
        insert(:internal_transaction_create,
          transaction: transaction1,
          index: index,
          block_hash: transaction1.block_hash,
          block_index: index
        )
      end

      insert(:internal_transaction_create,
        transaction: transaction2,
        index: 0,
        block_hash: transaction2.block_hash,
        block_index: 0
      )

      found_internal_transactions =
        transaction1
        |> GraphQL.transaction_to_internal_transactions_query()
        |> Repo.replica().all()

      assert length(found_internal_transactions) == 3

      for found_internal_transaction <- found_internal_transactions do
        assert found_internal_transaction.transaction_hash == transaction1.hash
      end
    end

    test "orders internal transactions by ascending index" do
      transaction = insert(:transaction) |> with_block()

      insert(:internal_transaction_create,
        transaction: transaction,
        index: 2,
        block_hash: transaction.block_hash,
        block_index: 2
      )

      insert(:internal_transaction_create,
        transaction: transaction,
        index: 0,
        block_hash: transaction.block_hash,
        block_index: 0
      )

      insert(:internal_transaction_create,
        transaction: transaction,
        index: 1,
        block_hash: transaction.block_hash,
        block_index: 1
      )

      found_internal_transactions =
        transaction
        |> GraphQL.transaction_to_internal_transactions_query()
        |> Repo.replica().all()

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

  describe "get_token_transfer/1" do
    test "returns existing token transfer" do
      transaction = insert(:transaction)
      token_transfer = insert(:token_transfer, transaction: transaction)

      clauses = %{transaction_hash: token_transfer.transaction_hash, log_index: token_transfer.log_index}

      {:ok, found_token_transfer} = GraphQL.get_token_transfer(clauses)

      assert found_token_transfer.transaction_hash == token_transfer.transaction_hash
      assert found_token_transfer.log_index == token_transfer.log_index
    end

    test " returns error tuple for non-existing token transfer" do
      transaction = insert(:transaction)
      token_transfer = build(:token_transfer, transaction: transaction)

      clauses = %{transaction_hash: transaction.hash, log_index: token_transfer.log_index}

      assert GraphQL.get_token_transfer(clauses) == {:error, "Token transfer not found."}
    end
  end

  describe "list_token_transfers_query/1" do
    test "with token contract address hash with zero token transfers" do
      result =
        :address
        |> insert()
        |> Map.get(:hash)
        |> GraphQL.list_token_transfers_query()
        |> Repo.replica().all()

      assert result == []
    end

    test "returns all expected token transfer fields" do
      transaction = insert(:transaction)
      token_transfer = insert(:token_transfer, transaction: transaction)

      [found_token_transfer] =
        token_transfer.token_contract_address_hash
        |> GraphQL.list_token_transfers_query()
        |> Repo.replica().all()

      expected_fields = ~w(
        amount
        block_number
        log_index
        token_id
        from_address_hash
        to_address_hash
        token_contract_address_hash
        transaction_hash
      )a

      for expected_field <- expected_fields do
        assert Map.get(found_token_transfer, expected_field) == Map.get(token_transfer, expected_field)
      end
    end

    test "orders token transfers by descending block number" do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)

      transactions_block2 =
        2
        |> insert_list(:transaction)
        |> with_block(second_block)

      transactions_block3 =
        2
        |> insert_list(:transaction)
        |> with_block(third_block)

      transactions_block1 =
        2
        |> insert_list(:transaction)
        |> with_block(first_block)

      all_transactions = Enum.concat([transactions_block2, transactions_block3, transactions_block1])

      token_address = insert(:contract_address)
      insert(:token, contract_address: token_address)

      for transaction <- all_transactions do
        token_transfer_attrs1 = %{
          block_number: transaction.block_number,
          log_index: 0,
          transaction: transaction,
          token_contract_address: token_address
        }

        token_transfer_attrs2 = %{
          block_number: transaction.block_number,
          log_index: 1,
          transaction: transaction,
          token_contract_address: token_address
        }

        insert(:token_transfer, token_transfer_attrs1)
        insert(:token_transfer, token_transfer_attrs2)
      end

      found_token_transfers =
        token_address.hash
        |> GraphQL.list_token_transfers_query()
        |> Repo.replica().all()
        |> Repo.replica().preload(:transaction)

      block_number_order = Enum.map(found_token_transfers, & &1.block_number)

      assert block_number_order == Enum.sort(block_number_order, &(&1 >= &2))
    end
  end
end
