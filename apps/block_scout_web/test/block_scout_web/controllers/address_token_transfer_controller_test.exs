defmodule BlockScoutWeb.AddressTokenTransferControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.Routers.WebRouter.Helpers,
    only: [address_token_transfers_path: 4, address_token_transfers_path: 5]

  alias Explorer.Chain.{Address, Token}

  describe "GET index/2" do
    test "with invalid address hash", %{conn: conn} do
      token_hash = "0xc8982771dd50285389c352c175ada74d074427c7"
      conn = get(conn, address_token_transfers_path(conn, :index, "invalid_address", token_hash))

      assert html_response(conn, 422)
    end

    test "with invalid token hash", %{conn: conn} do
      address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"

      conn = get(conn, address_token_transfers_path(conn, :index, Address.checksum(address_hash), "invalid_address"))

      assert html_response(conn, 422)
    end

    test "with an address that doesn't exist in our database", %{conn: conn} do
      address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      %Token{contract_address_hash: token_hash} = insert(:token)

      conn =
        get(
          conn,
          address_token_transfers_path(conn, :index, Address.checksum(address_hash), Address.checksum(token_hash))
        )

      assert html_response(conn, 404)
    end

    test "with an token that doesn't exist in our database", %{conn: conn} do
      %Address{hash: address_hash} = insert(:address)
      token_hash = Address.checksum("0x8bf38d4764929064f2d4d3a56520a76ab3df415b")
      conn = get(conn, address_token_transfers_path(conn, :index, Address.checksum(address_hash), token_hash))

      assert html_response(conn, 404)
    end
  end

  describe "GET index/2 JSON" do
    test "without token transfers for a token", %{conn: conn} do
      %Address{hash: address_hash} = insert(:address)
      %Token{contract_address_hash: token_hash} = insert(:token)

      conn =
        get(
          conn,
          address_token_transfers_path(conn, :index, Address.checksum(address_hash), Address.checksum(token_hash)),
          %{
            type: "JSON"
          }
        )

      assert json_response(conn, 200) == %{"items" => [], "next_page_path" => nil}
    end

    test "returns the correct number of transactions", %{conn: conn} do
      address = insert(:address)
      token = insert(:token)

      inserted_transactions =
        Enum.map(1..5, fn index ->
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

      conn =
        get(
          conn,
          address_token_transfers_path(
            conn,
            :index,
            Address.checksum(address.hash),
            Address.checksum(token.contract_address_hash)
          ),
          %{type: "JSON"}
        )

      response_items =
        conn
        |> json_response(200)
        |> Map.get("items")

      items_length = length(response_items)

      assert items_length == 5

      assert Enum.all?(inserted_transactions, fn transaction ->
               Enum.any?(response_items, fn item ->
                 String.contains?(
                   item,
                   "data-identifier-hash=\"#{to_string(transaction.hash)}\""
                 )
               end)
             end)
    end

    test "returns next_page_path as null when there are no more pages", %{conn: conn} do
      address = insert(:address)
      token = insert(:token)

      block = insert(:block, number: 1000)

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

      conn =
        get(
          conn,
          address_token_transfers_path(
            conn,
            :index,
            Address.checksum(address.hash),
            Address.checksum(token.contract_address_hash)
          ),
          %{type: "JSON"}
        )

      assert Map.get(json_response(conn, 200), "next_page_path") == nil
    end

    test "returns next_page_path when there are more items", %{conn: conn} do
      address = insert(:address)
      token = insert(:token)

      page_last_transfer =
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
        |> List.last()

      Enum.each(51..60, fn index ->
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
      end)

      conn =
        get(
          conn,
          address_token_transfers_path(
            conn,
            :index,
            Address.checksum(address.hash),
            Address.checksum(token.contract_address_hash)
          ),
          %{type: "JSON"}
        )

      expected_path =
        address_token_transfers_path(
          conn,
          :index,
          Address.checksum(address.hash),
          Address.checksum(token.contract_address_hash),
          index: page_last_transfer.index,
          block_number: page_last_transfer.block_number,
          items_count: "50"
        )

      assert Map.get(json_response(conn, 200), "next_page_path") == expected_path
    end

    test "with invalid address hash", %{conn: conn} do
      token_hash = "0xc8982771dd50285389c352c175ada74d074427c7"

      conn =
        get(conn, address_token_transfers_path(conn, :index, "invalid_address", token_hash), %{
          type: "JSON"
        })

      assert html_response(conn, 422)
    end

    test "with invalid token hash", %{conn: conn} do
      address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"

      conn =
        get(conn, address_token_transfers_path(conn, :index, Address.checksum(address_hash), "invalid_address"), %{
          type: "JSON"
        })

      assert html_response(conn, 422)
    end

    test "with an address that doesn't exist in our database", %{conn: conn} do
      address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      %Token{contract_address_hash: token_hash} = insert(:token)

      conn =
        get(
          conn,
          address_token_transfers_path(conn, :index, Address.checksum(address_hash), Address.checksum(token_hash)),
          %{
            type: "JSON"
          }
        )

      assert html_response(conn, 404)
    end

    test "with a token that doesn't exist in our database", %{conn: conn} do
      %Address{hash: address_hash} = insert(:address)
      token_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"

      conn =
        get(
          conn,
          address_token_transfers_path(conn, :index, Address.checksum(address_hash), Address.checksum(token_hash)),
          %{
            type: "JSON"
          }
        )

      assert html_response(conn, 404)
    end
  end
end
