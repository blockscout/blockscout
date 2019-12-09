defmodule BlockScoutWeb.Tokens.ReadContractControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  describe "GET index/3" do
    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, token_read_contract_path(BlockScoutWeb.Endpoint, :index, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "successfully renders the page when the token is a verified smart contract", %{conn: conn} do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        block: transaction.block,
        token_contract_address: token_contract_address,
        token: token
      )

      conn = get(conn, token_read_contract_path(BlockScoutWeb.Endpoint, :index, token.contract_address_hash))

      assert html_response(conn, 200)
      assert token.contract_address_hash == conn.assigns.token.contract_address_hash
      assert conn.assigns.total_token_transfers
      assert conn.assigns.total_token_holders
    end
  end
end
