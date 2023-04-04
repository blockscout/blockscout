defmodule BlockScoutWeb.Tokens.InstanceControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  describe "GET show/2" do
    test "redirects  with valid params", %{conn: conn} do
      token = insert(:token)

      contract_address_hash = token.contract_address_hash

      token_id = 10

      insert(:token_instance,
        token_contract_address_hash: contract_address_hash,
        token_id: token_id
      )

      conn = get(conn, token_instance_path(BlockScoutWeb.Endpoint, :show, to_string(contract_address_hash), token_id))

      assert conn.status == 302

      assert get_resp_header(conn, "location") == [
               "/token/#{contract_address_hash}/instance/#{token_id}/token-transfers"
             ]
    end
  end
end
