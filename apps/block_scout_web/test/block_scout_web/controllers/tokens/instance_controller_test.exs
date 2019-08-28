defmodule BlockScoutWeb.Tokens.InstanceControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  describe "GET show/2" do
    test "returns erc721 token with valid params", %{conn: conn} do
      contract_address = insert(:address)

      token_id = 10

      insert(:token_transfer,
        from_address: contract_address,
        token_contract_address: contract_address,
        token_id: token_id
      )

      conn =
        get(conn, token_instance_path(conn, :show, token_id, %{token_address_hash: to_string(contract_address.hash)}))

      assert conn.status == 200
    end
  end
end
