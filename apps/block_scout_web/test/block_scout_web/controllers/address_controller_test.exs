defmodule BlockScoutWeb.AddressControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Address, Wei}

  describe "GET index/2" do
    test "returns top addresses", %{conn: conn} do
      address_hashes =
        4..1
        |> Enum.map(&insert(:address, fetched_coin_balance: &1))
        |> Enum.map(& &1.hash)

      conn = get(conn, address_path(conn, :index))

      assert conn.assigns.addresses |> Enum.map(& &1.hash) == address_hashes
    end

    test "returns next page of results based on last seen address", %{conn: conn} do
      second_page_address_hashes =
        50..1
        |> Enum.map(&insert(:address, fetched_coin_balance: &1))
        |> Enum.map(& &1.hash)

      %Address{fetched_coin_balance: value, hash: address_hash} = insert(:address, fetched_coin_balance: 51)

      conn =
        get(conn, address_path(conn, :index), %{
          "address_hash" => to_string(address_hash),
          "value" => value |> Wei.to(:wei) |> Decimal.to_integer()
        })

      actual_address_hashes =
        conn.assigns.addresses
        |> Enum.map(& &1.hash)

      assert second_page_address_hashes == actual_address_hashes
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      %Address{fetched_coin_balance: value, hash: address_hash} =
        60..1
        |> Enum.map(&insert(:address, fetched_coin_balance: &1))
        |> Enum.fetch!(49)

      conn = get(conn, address_path(conn, :index))

      assert %{
               "address_hash" => to_string(address_hash),
               "value" => value |> Wei.to(:wei) |> Decimal.to_integer()
             } == conn.assigns.next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      insert(:address)

      conn = get(conn, address_path(conn, :index))

      refute conn.assigns.next_page_params
    end
  end

  describe "GET show/3" do
    test "redirects to address/:address_id/transactions", %{conn: conn} do
      insert(:address, hash: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")

      conn = get(conn, "/address/0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")

      assert redirected_to(conn) =~ "/address/0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed/transactions"
    end
  end
end
