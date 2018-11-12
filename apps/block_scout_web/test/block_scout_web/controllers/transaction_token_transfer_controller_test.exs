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

      expected_token_transfer = insert(:token_transfer, transaction: transaction)

      insert(:token_transfer, transaction: transaction)

      path = transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash)

      conn = get(conn, path)

      actual_token_transfer_primary_keys =
        conn.assigns.token_transfers
        |> Enum.map(&{&1.transaction_hash, &1.log_index})

      assert html_response(conn, 200)

      assert Enum.member?(
               actual_token_transfer_primary_keys,
               {expected_token_transfer.transaction_hash, expected_token_transfer.log_index}
             )
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

      {:ok, first_transfer_time} = NaiveDateTime.new(2000, 1, 1, 0, 0, 5)
      {:ok, remaining_transfers_time} = NaiveDateTime.new(1999, 1, 1, 0, 0, 0)
      insert(:token_transfer, transaction: transaction, inserted_at: first_transfer_time)

      1..5
      |> Enum.each(fn log_index ->
        insert(:token_transfer, transaction: transaction, inserted_at: remaining_transfers_time, log_index: log_index)
      end)

      conn =
        get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash), %{
          "inserted_at" => first_transfer_time |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()
        })

      actual_times =
        conn.assigns.token_transfers
        |> Enum.map(& &1.inserted_at)

      refute Enum.any?(actual_times, fn time -> first_transfer_time == time end)
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
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

      conn = get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

      assert Enum.any?(conn.assigns.next_page_params)
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
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

      conn = get(conn, transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

      assert is_nil(conn.assigns.next_page_params)
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
