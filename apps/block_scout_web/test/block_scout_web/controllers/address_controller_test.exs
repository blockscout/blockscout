defmodule BlockScoutWeb.AddressControllerTest do
  use BlockScoutWeb.ConnCase

  describe "GET index/2" do
    test "returns top addresses", %{conn: conn} do
      address_hashes =
        4..1
        |> Enum.map(&insert(:address, fetched_coin_balance: &1))
        |> Enum.map(& &1.hash)

      conn = get(conn, address_path(conn, :index))

      assert conn.assigns.addresses |> Enum.map(& &1.hash) == address_hashes
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
