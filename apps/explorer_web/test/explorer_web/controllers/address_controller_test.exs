defmodule ExplorerWeb.AddressControllerTest do
  use ExplorerWeb.ConnCase

  alias Explorer.Chain.{Credit, Debit}

  describe "GET show/3" do
    test "redirects to addresses/:address_id/transactions", %{conn: conn} do
      insert(:address, hash: "0x9")
      Credit.refresh()
      Debit.refresh()

      conn = get(conn, "/en/addresses/0x9")

      assert redirected_to(conn) =~ "/en/addresses/0x9/transactions"
    end
  end
end
