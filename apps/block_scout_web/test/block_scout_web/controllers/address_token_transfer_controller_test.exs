defmodule BlockScoutWeb.AddressTokenTransferControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.Router.Helpers, only: [address_token_transfers_path: 4]

  alias Explorer.Chain.{Address, Token}

  describe "GET index/2" do
    test "with invalid address hash", %{conn: conn} do
      token_hash = "0xc8982771dd50285389c352c175ada74d074427c7"
      conn = get(conn, address_token_transfers_path(conn, :index, "invalid_address", token_hash))

      assert html_response(conn, 422)
    end

    test "with invalid token hash", %{conn: conn} do
      address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      conn = get(conn, address_token_transfers_path(conn, :index, address_hash, "invalid_address"))

      assert html_response(conn, 422)
    end

    test "with an address that doesn't exist in our database", %{conn: conn} do
      address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      %Token{contract_address_hash: token_hash} = insert(:token)
      conn = get(conn, address_token_transfers_path(conn, :index, address_hash, token_hash))

      assert html_response(conn, 404)
    end

    test "with an token that doesn't exist in our database", %{conn: conn} do
      %Address{hash: address_hash} = insert(:address)
      token_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      conn = get(conn, address_token_transfers_path(conn, :index, address_hash, token_hash))

      assert html_response(conn, 404)
    end

    test "without token transfers for a token", %{conn: conn} do
      %Address{hash: address_hash} = insert(:address)
      %Token{contract_address_hash: token_hash} = insert(:token)

      conn = get(conn, address_token_transfers_path(conn, :index, address_hash, token_hash))

      assert html_response(conn, 200)
      assert conn.assigns.transactions == []
    end

    test "returns the transactions that have token transfers for the given address and token", %{conn: conn} do
      address = insert(:address)
      token = insert(:token)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        to_address: address,
        transaction: transaction,
        token_contract_address: token.contract_address
      )

      conn = get(conn, address_token_transfers_path(conn, :index, address.hash, token.contract_address_hash))

      transaction_hashes = Enum.map(conn.assigns.transactions, & &1.hash)

      assert html_response(conn, 200)
      assert transaction_hashes == [transaction.hash]
    end

    test "returns next page of results based on last seen transactions", %{conn: conn} do
      address = insert(:address)
      token = insert(:token)

      second_page_transactions =
        1..50
        |> Enum.map(fn index ->
          block = insert(:block, number: 1000 - index)

          transaction =
            :transaction
            |> insert()
            |> with_block(block)

          insert(
            :token_transfer,
            to_address: address,
            transaction: transaction,
            token_contract_address: token.contract_address
          )

          transaction
        end)
        |> Enum.map(& &1.hash)

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1002))

      conn =
        get(conn, address_token_transfers_path(conn, :index, address.hash, token.contract_address_hash), %{
          "block_number" => Integer.to_string(transaction.block_number),
          "index" => Integer.to_string(transaction.index)
        })

      actual_transactions = Enum.map(conn.assigns.transactions, & &1.hash)

      assert second_page_transactions == actual_transactions
    end
  end
end
