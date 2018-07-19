defmodule ExplorerWeb.AddressReadContractControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET show/3" do
    test "only responds to ajax requests", %{conn: conn} do
      smart_contract = insert(:smart_contract)

      path =
        address_read_contract_path(
          ExplorerWeb.Endpoint,
          :show,
          :en,
          smart_contract.address_hash,
          smart_contract.address_hash,
          function_name: "get",
          args: []
        )

      conn = get(conn, path)

      assert conn.status == 404
    end
  end
end
