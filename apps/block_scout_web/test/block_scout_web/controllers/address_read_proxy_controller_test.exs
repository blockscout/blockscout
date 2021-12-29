defmodule BlockScoutWeb.AddressReadProxyControllerTest do
  use BlockScoutWeb.ConnCase, async: true
  use ExUnit.Case, async: false

  alias Explorer.ExchangeRates.Token
  alias Explorer.Chain.Address

  import Mox

  describe "GET index/3" do
    setup :set_mox_global

    setup do
      configuration = Application.get_env(:explorer, :checksum_function)
      Application.put_env(:explorer, :checksum_function, :eth)

      :ok

      on_exit(fn ->
        Application.put_env(:explorer, :checksum_function, configuration)
      end)
    end

    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, address_read_proxy_path(BlockScoutWeb.Endpoint, :index, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "with valid address that is not a contract", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_read_proxy_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)))

      assert html_response(conn, 404)
    end

    test "successfully renders the page when the address is a contract", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction = insert(:transaction, from_address: contract_address) |> with_block()

      insert(
        :internal_transaction_create,
        index: 0,
        transaction: transaction,
        created_contract_address: contract_address,
        block_hash: transaction.block_hash,
        block_index: 0
      )

      insert(:smart_contract, address_hash: contract_address.hash)

      get_eip1967_implementation()

      conn = get(conn, address_read_proxy_path(BlockScoutWeb.Endpoint, :index, Address.checksum(contract_address.hash)))

      assert html_response(conn, 200)
      assert contract_address.hash == conn.assigns.address.hash
      assert %Token{} = conn.assigns.exchange_rate
    end

    test "returns not found for an unverified contract", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction = insert(:transaction, from_address: contract_address) |> with_block()

      insert(
        :internal_transaction_create,
        index: 0,
        transaction: transaction,
        created_contract_address: contract_address,
        block_hash: transaction.block_hash,
        block_index: 0
      )

      conn = get(conn, address_read_proxy_path(BlockScoutWeb.Endpoint, :index, Address.checksum(contract_address.hash)))

      assert html_response(conn, 404)
    end
  end

  def get_eip1967_implementation do
    EthereumJSONRPC.Mox
    |> expect(
      :json_rpc,
      fn [%{id: id, method: "eth_getCode", params: [_, _]}], _options ->
        {:ok, [%{id: id, jsonrpc: "2.0", result: "0x0"}]}
      end
    )
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
