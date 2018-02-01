defmodule ExplorerWeb.AddressControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET show/3" do
    test "returns an address", %{conn: conn} do
      address = insert(:address, hash: "0x9")
      conn = get(conn, "/en/addresses/0x9")
      assert conn.assigns.address.id == address.id
    end
  end
end
