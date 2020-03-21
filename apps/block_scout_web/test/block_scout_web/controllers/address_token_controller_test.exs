defmodule BlockScoutWeb.AddressTokenControllerTest do
  use BlockScoutWeb.ConnCase, async: true

  import BlockScoutWeb.WebRouter.Helpers, only: [address_token_path: 3]
  import Mox

  alias Explorer.Chain.{Address, Token}

  describe "GET index/2" do
    setup :set_mox_global

    setup do
      configuration = Application.get_env(:explorer, :checksum_function)
      Application.put_env(:explorer, :checksum_function, :eth)

      :ok

      on_exit(fn ->
        Application.put_env(:explorer, :checksum_function, configuration)
      end)
    end

    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, address_token_path(conn, :index, "invalid_address"))

      assert html_response(conn, 422)
    end

    test "with valid address hash without address", %{conn: conn} do
      conn = get(conn, address_token_path(conn, :index, Address.checksum("0x8bf38d4764929064f2d4d3a56520a76ab3df415b")))

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

      conn = get(conn, address_token_path(conn, :index, Address.checksum(address)), type: "JSON")

      {:ok, %{"items" => items}} =
        conn.resp_body
        |> Poison.decode()

      assert json_response(conn, 200)
      assert Enum.any?(items, fn item -> String.contains?(item, to_string(token1.contract_address_hash)) end)
      refute Enum.any?(items, fn item -> String.contains?(item, to_string(token2.contract_address_hash)) end)
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

      conn =
        get(conn, address_token_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)), %{
          "token_name" => name,
          "token_type" => type,
          "token_inserted_at" => inserted_at,
          "type" => "JSON"
        })

      {:ok, %{"items" => items}} =
        conn.resp_body
        |> Poison.decode()

      assert Enum.any?(items, fn item ->
               Enum.any?(second_page_tokens, fn token_name -> String.contains?(item, token_name) end)
             end)
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

      conn = get(conn, address_token_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)), type: "JSON")

      {:ok, %{"next_page_path" => next_page_path}} =
        conn.resp_body
        |> Poison.decode()

      assert next_page_path
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      address = insert(:address)
      token = insert(:token)
      insert(:token_transfer, token_contract_address: token.contract_address, from_address: address)

      conn = get(conn, address_token_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)), type: "JSON")

      {:ok, %{"next_page_path" => next_page_path}} =
        conn.resp_body
        |> Poison.decode()

      refute next_page_path
    end
  end
end
