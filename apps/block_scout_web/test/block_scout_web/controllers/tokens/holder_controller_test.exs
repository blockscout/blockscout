defmodule BlockScoutWeb.Tokens.HolderControllerTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.Chain.{Address, Hash}

  describe "GET index/3" do
    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, token_holder_path(BlockScoutWeb.Endpoint, :index, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "with a token that doesn't exist", %{conn: conn} do
      address = build(:address)
      conn = get(conn, token_holder_path(BlockScoutWeb.Endpoint, :index, address.hash))

      assert html_response(conn, 404)
    end

    test "successfully renders the page", %{conn: conn} do
      token = insert(:token)

      insert_list(
        2,
        :address_current_token_balance,
        token_contract_address_hash: token.contract_address_hash
      )

      conn =
        get(
          conn,
          token_holder_path(BlockScoutWeb.Endpoint, :index, token.contract_address_hash)
        )

      assert html_response(conn, 200)
    end

    test "returns next page of results based on last seen token balance", %{conn: conn} do
      contract_address = build(:contract_address, hash: "0x6937cb25eb54bc013b9c13c47ab38eb63edd1493")
      token = insert(:token, contract_address: contract_address)

      second_page_token_balances =
        1..50
        |> Enum.map(
          &insert(
            :address_current_token_balance,
            token_contract_address_hash: token.contract_address_hash,
            value: &1 + 1000
          )
        )

      token_balance =
        insert(
          :address_current_token_balance,
          token_contract_address_hash: token.contract_address_hash,
          value: 50000
        )

      conn =
        get(conn, token_holder_path(conn, :index, token.contract_address_hash), %{
          "value" => Decimal.to_integer(token_balance.value),
          "address_hash" => Hash.to_string(token_balance.address_hash),
          "type" => "JSON"
        })

      token_balance_tiles = json_response(conn, 200)["items"]

      assert Enum.all?(second_page_token_balances, fn token_balance ->
               Enum.any?(token_balance_tiles, fn tile ->
                 String.contains?(tile, Address.checksum(token_balance.address_hash))
               end)
             end)
    end

    test "next_page_params exists if not on last page", %{conn: conn} do
      contract_address = build(:contract_address, hash: "0x6937cb25eb54bc013b9c13c47ab38eb63edd1493")
      token = insert(:token, contract_address: contract_address)

      Enum.each(
        1..51,
        &insert(
          :address_current_token_balance,
          token_contract_address_hash: token.contract_address_hash,
          value: &1 + 1000
        )
      )

      conn = get(conn, token_holder_path(conn, :index, token.contract_address_hash, %{"type" => "JSON"}))

      assert json_response(conn, 200)["next_page_path"]
    end
  end
end
