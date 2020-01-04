defmodule BlockScoutWeb.TransactionInternalTransactionControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.WebRouter.Helpers, only: [transaction_internal_transaction_path: 3]

  alias Explorer.Chain.InternalTransaction
  alias Explorer.ExchangeRates.Token

  describe "GET index/3" do
    test "with missing transaction", %{conn: conn} do
      hash = transaction_hash()
      conn = get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, hash))

      assert html_response(conn, 404)
    end

    test "with invalid transaction hash", %{conn: conn} do
      conn = get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, "nope"))

      assert html_response(conn, 422)
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

      insert(:internal_transaction,
        transaction: transaction,
        index: 0,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash,
        block_index: 0
      )

      insert(:internal_transaction,
        transaction: transaction,
        index: 1,
        transaction_index: transaction.index,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 1
      )

      path = transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction.hash)

      conn = get(conn, path, %{type: "JSON"})

      {:ok, %{"items" => items}} =
        conn.resp_body
        |> Poison.decode()

      assert json_response(conn, 200)

      # excluding of internal transactions with type=call and index=0
      assert Enum.count(items) == 1
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
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 0
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
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 0
        )

      second_page_indexes =
        1..50
        |> Enum.map(fn index ->
          insert(:internal_transaction,
            transaction: transaction,
            index: index,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            block_hash: transaction.block_hash,
            block_index: index
          )
        end)
        |> Enum.map(& &1.index)

      conn =
        get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction.hash), %{
          "index" => Integer.to_string(index),
          "type" => "JSON"
        })

      {:ok, %{"items" => items}} =
        conn.resp_body
        |> Poison.decode()

      assert Enum.count(items) == Enum.count(second_page_indexes)
    end

    test "next_page_path exists if not on last page", %{conn: conn} do
      block = insert(:block, number: 7000)

      transaction =
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
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: index
        )
      end)

      conn =
        get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction.hash), %{
          type: "JSON"
        })

      {:ok, %{"next_page_path" => next_page_path}} =
        conn.resp_body
        |> Poison.decode()

      assert next_page_path
    end

    test "next_page_path is empty if on last page", %{conn: conn} do
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
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: index
        )
      end)

      conn =
        get(conn, transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction.hash), %{
          type: "JSON"
        })

      {:ok, %{"next_page_path" => next_page_path}} =
        conn.resp_body
        |> Poison.decode()

      refute next_page_path
    end
  end
end
