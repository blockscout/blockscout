defmodule BlockScoutWeb.Tokens.InstanceControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  describe "GET show/2" do
    test "redirects  with valid params", %{conn: conn} do
      contract_address = insert(:address)
      block = insert(:block)

      insert(:token, contract_address: contract_address)

      token_id = 10

      insert(:token_transfer,
        from_address: contract_address,
        token_contract_address: contract_address,
        block: block,
        token_id: token_id
      )

      conn = get(conn, token_instance_path(BlockScoutWeb.Endpoint, :show, to_string(contract_address.hash), token_id))

      assert conn.status == 302
    end

    test "works for ERC-1155 tokens", %{conn: conn} do
      contract_address = insert(:address)

      insert(:token, contract_address: contract_address)

      token_id = 10

      insert(:token_transfer,
        from_address: contract_address,
        token_contract_address: contract_address,
        token_id: nil,
        token_ids: [token_id]
      )

      conn = get(conn, token_instance_path(BlockScoutWeb.Endpoint, :show, to_string(contract_address.hash), token_id))

      assert conn.status == 302

      assert get_resp_header(conn, "location") == [
               "/token/#{contract_address.hash}/instance/#{token_id}/token-transfers"
             ]
    end
  end
end
