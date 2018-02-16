defmodule ExplorerWeb.AddressControllerTest do
  use ExplorerWeb.ConnCase

  alias Explorer.Credit
  alias Explorer.Debit

  describe "GET show/3" do
    test "returns an address", %{conn: conn} do
      address = insert(:address, hash: "0x9")
      Credit.refresh
      Debit.refresh
      conn = get(conn, "/en/addresses/0x9")
      assert conn.assigns.address.id == address.id
    end
  end
end
