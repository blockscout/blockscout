defmodule BlockScoutWeb.Tokens.InstanceControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  describe "GET show/2" do
    test "redirects  with valid params", %{conn: conn} do
      contract_address = insert(:address)

      insert(:token, contract_address: contract_address)

      token_id = 10

      insert(:token_transfer,
        from_address: contract_address,
        token_contract_address: contract_address,
        token_id: token_id
      )

      conn = get(conn, token_instance_path(BlockScoutWeb.Endpoint, :show, to_string(contract_address.hash), token_id))

      assert conn.status == 302
    end
  end
end
