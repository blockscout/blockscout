defmodule BlockScoutWeb.AddressTokenControllerTest do
  use BlockScoutWeb.ConnCase,
    # ETS table is shared in `Explorer.Counters.BlockValidationCounter`
    async: false

  import BlockScoutWeb.Router.Helpers, only: [address_token_path: 3]

  alias Explorer.Chain.{Token}
  alias Explorer.Counters.BlockValidationCounter

  describe "GET index/2" do
    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, address_token_path(conn, :index, "invalid_address"))

      assert html_response(conn, 422)
    end

    test "with valid address hash without address", %{conn: conn} do
      conn = get(conn, address_token_path(conn, :index, "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"))

      assert html_response(conn, 404)
    end

    test "returns tokens that have balance for the address", %{conn: conn} do
      address = insert(:address)

      token1 =
        :token
        |> insert(name: "token1")

      token2 =
        :token
        |> insert(name: "token2")

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token1.contract_address_hash,
        value: 1000
      )

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token2.contract_address_hash,
        value: 0
      )

      insert(
        :token_transfer,
        token_contract_address: token1.contract_address,
        from_address: address,
        to_address: build(:address)
      )

      insert(
        :token_transfer,
        token_contract_address: token2.contract_address,
        from_address: build(:address),
        to_address: address
      )

      start_supervised!(BlockValidationCounter)

      conn = get(conn, address_token_path(conn, :index, address))

      actual_token_hashes =
        conn.assigns.tokens
        |> Enum.map(& &1.contract_address_hash)

      assert html_response(conn, 200)
      assert Enum.member?(actual_token_hashes, token1.contract_address_hash)
      refute Enum.member?(actual_token_hashes, token2.contract_address_hash)
    end

    test "returns next page of results based on last seen token", %{conn: conn} do
      address = insert(:address)

      second_page_tokens =
        1..50
        |> Enum.reduce([], fn i, acc ->
          token = insert(:token, name: "A Token#{i}", type: "ERC-20")

          insert(
            :address_current_token_balance,
            token_contract_address_hash: token.contract_address_hash,
            address: address,
            value: 1000
          )

          acc ++ [token.name]
        end)
        |> Enum.sort()

      token = insert(:token, name: "Another Token", type: "ERC-721")

      insert(
        :address_current_token_balance,
        token_contract_address_hash: token.contract_address_hash,
        address: address,
        value: 1000
      )

      %Token{name: name, type: type, inserted_at: inserted_at} = token

      start_supervised!(BlockValidationCounter)

      conn =
        get(conn, address_token_path(BlockScoutWeb.Endpoint, :index, address.hash), %{
          "token_name" => name,
          "token_type" => type,
          "token_inserted_at" => inserted_at
        })

      actual_tokens =
        conn.assigns.tokens
        |> Enum.map(& &1.name)
        |> Enum.sort()

      assert second_page_tokens == actual_tokens
    end

    test "next_page_params exists if not on last page", %{conn: conn} do
      address = insert(:address)

      Enum.each(1..51, fn i ->
        token = insert(:token, name: "A Token#{i}", type: "ERC-20")

        insert(
          :address_current_token_balance,
          token_contract_address_hash: token.contract_address_hash,
          address: address,
          value: 1000
        )

        insert(:token_transfer, token_contract_address: token.contract_address, from_address: address)
      end)

      start_supervised!(BlockValidationCounter)

      conn = get(conn, address_token_path(BlockScoutWeb.Endpoint, :index, address.hash))

      assert conn.assigns.next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      address = insert(:address)
      token = insert(:token)
      insert(:token_transfer, token_contract_address: token.contract_address, from_address: address)

      start_supervised!(BlockValidationCounter)

      conn = get(conn, address_token_path(BlockScoutWeb.Endpoint, :index, address.hash))

      refute conn.assigns.next_page_params
    end
  end
end
