defmodule BlockScoutWeb.Tokens.Instance.TransferControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  describe "GET token-transfers/2" do
    test "works for ERC-721 tokens", %{conn: conn} do
      contract_address = insert(:address)

      insert(:token, contract_address: contract_address)

      token_id = 10

      %{log_index: log_index} =
        insert(:token_transfer,
          from_address: contract_address,
          token_contract_address: contract_address,
          token_id: token_id
        )

      conn = get(conn, "/token/#{contract_address.hash}/instance/#{token_id}/token-transfers")

      assert %{assigns: %{token_instance: %{log_index: ^log_index}}} = conn
    end

    test "works for ERC-1155 tokens", %{conn: conn} do
      contract_address = insert(:address)

      insert(:token, contract_address: contract_address)

      token_id = 10

      %{log_index: log_index} =
        insert(:token_transfer,
          from_address: contract_address,
          token_contract_address: contract_address,
          token_id: nil,
          token_ids: [token_id]
        )

      conn = get(conn, "/token/#{contract_address.hash}/instance/#{token_id}/token-transfers")

      assert %{assigns: %{token_instance: %{log_index: ^log_index}}} = conn
    end
  end
end
