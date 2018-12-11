defmodule BlockScoutWeb.Tokens.InventoryControllerTest do
  use BlockScoutWeb.ConnCase

  describe "GET index/3" do
    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, token_inventory_path(conn, :index, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "with a token that doesn't exist", %{conn: conn} do
      address = build(:address)
      conn = get(conn, token_inventory_path(conn, :index, address.hash))

      assert html_response(conn, 404)
    end

    test "successfully renders the page", %{conn: conn} do
      token_contract_address = insert(:contract_address)
      token = insert(:token, type: "ERC-721", contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      conn =
        get(
          conn,
          token_inventory_path(conn, :index, token_contract_address.hash)
        )

      assert html_response(conn, 200)
    end

    test "returns next page of results based on last seen token balance", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      second_page_token_balances =
        Enum.map(
          1..50,
          &insert(
            :token_transfer,
            transaction: transaction,
            token_contract_address: token.contract_address,
            token: token,
            token_id: &1 + 1000
          )
        )

      conn =
        get(conn, token_inventory_path(conn, :index, token.contract_address_hash), %{
          "token_id" => "999"
        })

      assert Enum.map(conn.assigns.unique_tokens, & &1.token_id) == Enum.map(second_page_token_balances, & &1.token_id)
    end

    test "next_page_params exists if not on last page", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      Enum.each(
        1..51,
        &insert(
          :token_transfer,
          transaction: transaction,
          token_contract_address: token.contract_address,
          token: token,
          token_id: &1 + 1000
        )
      )

      expected_next_page_params = %{
        "token_id" => to_string(token.contract_address_hash),
        "unique_token" => 1050
      }

      conn = get(conn, token_inventory_path(conn, :index, token.contract_address_hash))

      assert conn.assigns.next_page_params == expected_next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        transaction: transaction,
        token_contract_address: token.contract_address,
        token: token,
        token_id: 1000
      )

      conn = get(conn, token_inventory_path(conn, :index, token.contract_address_hash))

      refute conn.assigns.next_page_params
    end
  end
end
