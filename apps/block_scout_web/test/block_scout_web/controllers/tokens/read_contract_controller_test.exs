defmodule BlockScoutWeb.Tokens.ContractControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  import Mox

  describe "GET index/3" do
    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, token_read_contract_path(BlockScoutWeb.Endpoint, :index, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "with unverified address hash returns not found", %{conn: conn} do
      address = insert(:address)

      token = insert(:token, contract_address: address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: address,
        token: token
      )

      conn = get(conn, token_read_contract_path(BlockScoutWeb.Endpoint, :index, token.contract_address_hash))

      assert html_response(conn, 404)
    end

    test "successfully renders the page when the token is a verified smart contract", %{conn: conn} do
      token_contract_address = insert(:contract_address)

      insert(:smart_contract, address_hash: token_contract_address.hash)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      get_eip1967_implementation()

      conn = get(conn, token_read_contract_path(BlockScoutWeb.Endpoint, :index, token.contract_address_hash))

      assert html_response(conn, 200)
      assert token.contract_address_hash == conn.assigns.token.contract_address_hash
    end
  end

  def get_eip1967_implementation do
    EthereumJSONRPC.Mox
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
  end
end
