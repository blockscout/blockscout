defmodule BlockScoutWeb.Tokens.InventoryControllerTest do
  use BlockScoutWeb.ConnCase, async: false

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
        Enum.map(1..50, fn i ->
          insert(
            :token_transfer,
            transaction: transaction,
            token_contract_address: token.contract_address,
            token: token,
            token_ids: [i + 1000]
          )

          insert(
            :token_instance,
            token_contract_address_hash: token.contract_address.hash,
            token_id: i + 1000
          )
        end)

      conn =
        get(conn, token_inventory_path(conn, :index, token.contract_address_hash), %{
          "token_id" => "999",
          "type" => "JSON"
        })

      conn = get(conn, token_inventory_path(conn, :index, token.contract_address_hash), %{type: "JSON"})

      {:ok, %{"items" => items}} =
        conn.resp_body
        |> Poison.decode()

      assert Enum.count(items) == Enum.count(second_page_token_balances)
    end

    test "next_page_path exists if not on last page", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      Enum.each(1..51, fn i ->
        insert(
          :token_transfer,
          transaction: transaction,
          token_contract_address: token.contract_address,
          token: token,
          token_ids: [i + 1000]
        )

        insert(
          :token_instance,
          token_contract_address_hash: token.contract_address.hash,
          token_id: i + 1000
        )
      end)

      conn = get(conn, token_inventory_path(conn, :index, token.contract_address_hash), %{type: "JSON"})

      {:ok, %{"next_page_path" => next_page_path}} =
        conn.resp_body
        |> Poison.decode()

      assert next_page_path
    end

    test "next_page_path is empty if on last page", %{conn: conn} do
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

      conn = get(conn, token_inventory_path(conn, :index, token.contract_address_hash), %{type: "JSON"})

      {:ok, %{"next_page_path" => next_page_path}} =
        conn.resp_body
        |> Poison.decode()

      refute next_page_path
    end
  end
end
