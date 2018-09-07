defmodule BlockScoutWeb.AddressControllerTest do
  use BlockScoutWeb.ConnCase

  describe "GET show/3" do
    test "redirects to address/:address_id/transactions", %{conn: conn} do
      insert(:address, hash: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")

      conn = get(conn, "/address/0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")

      assert redirected_to(conn) =~ "/en/address/0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed/transactions"
    end
  end
end
