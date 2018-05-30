defmodule ExplorerWeb.AddressQRCodeControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_qr_code_path: 4]

  describe "GET index/3" do
    test "with valid address hash returns a QR code", %{conn: conn} do
      conn = get(conn, address_qr_code_path(conn, :index, :en, address_hash()))

      assert response(conn, 200)
    end

    test "with invalid address hash returns 404", %{conn: conn} do
      conn = get(conn, address_qr_code_path(conn, :index, :en, "0xhaha"))

      assert response(conn, 404)
    end
  end
end
