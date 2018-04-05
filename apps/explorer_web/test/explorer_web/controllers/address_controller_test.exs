defmodule ExplorerWeb.AddressControllerTest do
  use ExplorerWeb.ConnCase

  alias Explorer.Chain.{Credit, Debit}

  describe "GET show/3" do
    test "without address returns not found", %{conn: conn} do
      conn = get(conn, "/en/addresses/unknown")

      assert html_response(conn, 404)
    end

    test "with address returns an address", %{conn: conn} do
      address = insert(:address, hash: "0x9")
      Credit.refresh()
      Debit.refresh()

      conn = get(conn, "/en/addresses/0x9")

      assert conn.assigns.address.id == address.id
    end
  end
end
