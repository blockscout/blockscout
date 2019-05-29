defmodule BlockScoutWeb.TransactionTokenTransferControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.Router.Helpers, only: [transaction_token_transfer_path: 3]

  alias Explorer.ExchangeRates.Token

  describe "GET index/3" do
    test "load token transfers", %{conn: conn} do
      transaction = insert(:transaction)
      token_transfer = insert(:token_transfer, transaction: transaction)

      conn = get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

      assigned_token_transfer = List.first(conn.assigns.transaction.token_transfers)

      assert {assigned_token_transfer.transaction_hash, assigned_token_transfer.log_index} ==
               {token_transfer.transaction_hash, token_transfer.log_index}
    end

    test "with missing transaction", %{conn: conn} do
      hash = transaction_hash()
      conn = get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, hash))

      assert html_response(conn, 404)
    end

    test "with invalid transaction hash", %{conn: conn} do
      conn = get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, "nope"))

      assert html_response(conn, 422)
    end

    test "includes transaction data", %{conn: conn} do
      block = insert(:block, %{number: 777})

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      conn = get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

      assert html_response(conn, 200)
      assert conn.assigns.transaction.hash == transaction.hash
    end

    test "includes token transfers for the transaction", %{conn: conn} do
      transaction = insert(:transaction)

      insert(:token_transfer, transaction: transaction)

      insert(:token_transfer, transaction: transaction)

      path = transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash)

      conn = get(conn, path, %{type: "JSON"})

      assert json_response(conn, 200)

      {:ok, %{"items" => items}} = conn.resp_body |> Poison.decode()

      assert Enum.count(items) == 2
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      transaction = insert(:transaction)

      conn = get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

      assert %Token{} = conn.assigns.exchange_rate
    end

    test "returns next page of results based on last seen token transfer", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer, transaction: transaction, block_number: 1000, log_index: 1)

      Enum.each(2..5, fn item ->
        insert(:token_transfer, transaction: transaction, block_number: item + 1001, log_index: item + 1)
      end)

      conn =
        get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash), %{
          "block_number" => "1000",
          "index" => "1",
          "type" => "JSON"
        })

      {:ok, %{"items" => items}} = conn.resp_body |> Poison.decode()

      refute Enum.count(items) == 3
    end

    test "next_page_path exists if not on last page", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      1..51
      |> Enum.map(fn log_index ->
        insert(
          :token_transfer,
          transaction: transaction,
          log_index: log_index
        )
      end)

      conn =
        get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash), %{type: "JSON"})

      {:ok, %{"next_page_path" => path}} = conn.resp_body |> Poison.decode()

      assert path
    end

    test "next_page_path is empty if on last page", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      1..2
      |> Enum.map(fn log_index ->
        insert(
          :token_transfer,
          transaction: transaction,
          log_index: log_index
        )
      end)

      conn =
        get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash), %{type: "JSON"})

      {:ok, %{"next_page_path" => path}} = conn.resp_body |> Poison.decode()

      refute path
    end

    test "preloads to_address smart contract verified", %{conn: conn} do
      transaction = insert(:transaction_to_verified_contract)

      conn = get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

      assert html_response(conn, 200)
      assert conn.assigns.transaction.hash == transaction.hash
      assert conn.assigns.transaction.to_address.smart_contract != nil
    end
  end
end
