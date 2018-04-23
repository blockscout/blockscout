defmodule ExplorerWeb.AddressControllerTest do
  use ExplorerWeb.ConnCase

  alias Explorer.Chain.{Credit, Debit}

  describe "GET show/3" do
    test "without address returns not found", %{conn: conn} do
      conn = get(conn, "/en/addresses/unknown")

      assert html_response(conn, 404)
    end

    test "with address returns an address", %{conn: conn} do
      address = insert(:address, hash: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
      Credit.refresh()
      Debit.refresh()

      conn = get(conn, "/en/addresses/0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")

      assert conn.assigns.address.hash == address.hash
    end
  end
end
