defmodule BlockScoutWeb.SmartContractControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Factory

  setup :verify_on_exit!

  describe "GET index/3" do
    test "returns not found for nonexistent address" do
      nonexistent_address_hash = Hash.to_string(Factory.address_hash())
      path = smart_contract_path(BlockScoutWeb.Endpoint, :index, hash: nonexistent_address_hash)

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert html_response(conn, 404)
    end

    test "error for invalid address" do
      path = smart_contract_path(BlockScoutWeb.Endpoint, :index, hash: "0x00")

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert conn.status == 422
    end

    test "only responds to ajax requests", %{conn: conn} do
      smart_contract = insert(:smart_contract)

      path = smart_contract_path(BlockScoutWeb.Endpoint, :index, hash: smart_contract.address_hash)

      conn = get(conn, path)

      assert conn.status == 404
    end

    test "lists the smart contract read only functions" do
      token_contract_address = insert(:contract_address)

      insert(:smart_contract, address_hash: token_contract_address.hash)

      blockchain_get_function_mock()

      path = smart_contract_path(BlockScoutWeb.Endpoint, :index, hash: token_contract_address.hash)

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert conn.status == 200
      refute conn.assigns.read_only_functions == []
    end
  end

  describe "GET show/3" do
    test "returns not found for nonexistent address" do
      nonexistent_address_hash = Address.checksum(Hash.to_string(Factory.address_hash()))

      path =
        smart_contract_path(
          BlockScoutWeb.Endpoint,
          :show,
          nonexistent_address_hash,
          function_name: "get",
          args: []
        )

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert html_response(conn, 404)
    end

    test "error for invalid address" do
      path =
        smart_contract_path(
          BlockScoutWeb.Endpoint,
          :show,
          "0x00",
          function_name: "get",
          args: []
        )

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert conn.status == 422
    end

    test "only responds to ajax requests", %{conn: conn} do
      smart_contract = insert(:smart_contract)

      path =
        smart_contract_path(
          BlockScoutWeb.Endpoint,
          :show,
          Address.checksum(smart_contract.address_hash),
          function_name: "get",
          args: []
        )

      conn = get(conn, path)

      assert conn.status == 404
    end

    test "fetch the function value from the blockchain" do
      address = insert(:contract_address)
      smart_contract = insert(:smart_contract, address_hash: address.hash)

      blockchain_get_function_mock()

      path =
        smart_contract_path(
          BlockScoutWeb.Endpoint,
          :show,
          Address.checksum(smart_contract.address_hash),
          function_name: "get",
          args: []
        )

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert conn.status == 200

      assert %{
               function_name: "get",
               layout: false,
               outputs: [%{"name" => "", "type" => "uint256", "value" => 0}]
             } = conn.assigns
    end
  end

  defp blockchain_get_function_mock do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
        {:ok, [%{id: id, jsonrpc: "2.0", result: "0x0000000000000000000000000000000000000000000000000000000000000000"}]}
      end
    )
  end
end
