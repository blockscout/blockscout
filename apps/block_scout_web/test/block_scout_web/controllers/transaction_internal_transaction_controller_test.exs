defmodule BlockScoutWeb.TransactionInternalTransactionControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.Router.Helpers, only: [transaction_internal_transaction_path: 3]

  alias Explorer.Chain.{Block, InternalTransaction, Transaction}
  alias Explorer.ExchangeRates.Token

  describe "GET index/3" do
    test "with missing transaction", %{conn: conn} do
      hash = transaction_hash()
      conn = get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, hash))

      assert html_response(conn, 404)
    end

    test "with invalid transaction hash", %{conn: conn} do
      conn = get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, "nope"))

      assert html_response(conn, 404)
    end

    test "includes transaction data", %{conn: conn} do
      block = insert(:block, %{number: 777})

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      conn = get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

      assert html_response(conn, 200)
      assert conn.assigns.transaction.hash == transaction.hash
    end

    test "includes internal transactions for the transaction", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      expected_internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )

      insert(:internal_transaction,
        transaction: transaction,
        index: 1,
        transaction_index: transaction.index,
        block_number: transaction.block_number
      )

      path = transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction.hash)

      conn = get(conn, path)

      actual_internal_transaction_primary_keys =
        Enum.map(conn.assigns.internal_transactions, &{&1.transaction_hash, &1.index})

      assert html_response(conn, 200)

      assert {expected_internal_transaction.transaction_hash, expected_internal_transaction.index} in actual_internal_transaction_primary_keys
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      transaction = insert(:transaction)

      conn = get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

      assert %Token{} = conn.assigns.exchange_rate
    end

    test "with no to_address_hash overview contains contract create address", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block(insert(:block, number: 7000))

      internal_transaction =
        :internal_transaction_create
        |> insert(
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )
        |> with_contract_creation(contract_address)

      conn =
        get(
          conn,
          transaction_internal_transaction_path(
            BlockScoutWeb.Endpoint,
            :index,
            internal_transaction.transaction_hash
          )
        )

      refute is_nil(conn.assigns.transaction.created_contract_address_hash)
    end

    test "returns next page of results based on last seen internal transaction", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 7000))

      %InternalTransaction{index: index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )

      second_page_indexes =
        1..50
        |> Enum.map(fn index ->
          insert(:internal_transaction,
            transaction: transaction,
            index: index,
            block_number: transaction.block_number,
            transaction_index: transaction.index
          )
        end)
        |> Enum.map(& &1.index)

      conn =
        get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction.hash), %{
          "index" => Integer.to_string(index)
        })

      actual_indexes =
        conn.assigns.internal_transactions
        |> Enum.map(& &1.index)

      assert second_page_indexes == actual_indexes
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      block = %Block{number: number} = insert(:block, number: 7000)

      transaction =
        %Transaction{index: transaction_index} =
        :transaction
        |> insert()
        |> with_block(block)

      1..60
      |> Enum.map(fn index ->
        insert(
          :internal_transaction,
          transaction: transaction,
          index: index,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )
      end)

      conn = get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

      assert %{"block_number" => ^number, "index" => 50, "transaction_index" => ^transaction_index} =
               conn.assigns.next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 7000))

      1..2
      |> Enum.map(fn index ->
        insert(
          :internal_transaction,
          transaction: transaction,
          index: index,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )
      end)

      conn = get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

      refute conn.assigns.next_page_params
    end
  end
end
