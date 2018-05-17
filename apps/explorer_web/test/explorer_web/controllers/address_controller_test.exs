defmodule ExplorerWeb.AddressControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET show/3" do
    test "redirects to addresses/:address_id/transactions", %{conn: conn} do
      insert(:address, hash: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")

      conn = get(conn, "/en/addresses/0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")

      assert redirected_to(conn) =~ "/en/addresses/0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed/transactions"
    end
  end
end
