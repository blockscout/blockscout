defmodule BlockScoutWeb.SmartContractControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.{Factory, TestHelper}

  setup :set_mox_from_context

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
      path = smart_contract_path(BlockScoutWeb.Endpoint, :index, hash: "0x00", type: :regular, action: :read)

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert conn.status == 422
    end

    test "only responds to ajax requests", %{conn: conn} do
      smart_contract = insert(:smart_contract, contract_code_md5: "123")

      path = smart_contract_path(BlockScoutWeb.Endpoint, :index, hash: smart_contract.address_hash)

      conn = get(conn, path)

      assert conn.status == 404
    end

    test "lists the smart contract read only functions" do
      token_contract_address = insert(:contract_address)

      insert(:smart_contract, address_hash: token_contract_address.hash, contract_code_md5: "123")

      blockchain_get_function_mock()

      path =
        smart_contract_path(BlockScoutWeb.Endpoint, :index,
          hash: token_contract_address.hash,
          type: :regular,
          action: :read
        )

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert conn.status == 200
      refute conn.assigns.read_only_functions == []
    end

    test "lists [] proxy read only functions if no verified implementation" do
      token_contract_address = insert(:contract_address)

      insert(:smart_contract,
        address_hash: token_contract_address.hash,
        abi: [
          %{
            "type" => "function",
            "stateMutability" => "view",
            "payable" => false,
            "outputs" => [%{"type" => "address", "name" => ""}],
            "name" => "implementation",
            "inputs" => [],
            "constant" => true
          }
        ],
        contract_code_md5: "123"
      )

      TestHelper.get_all_proxies_implementation_zero_addresses()

      path =
        smart_contract_path(BlockScoutWeb.Endpoint, :index,
          hash: token_contract_address.hash,
          type: :proxy,
          action: :read
        )

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert conn.status == 200
      assert conn.assigns.read_only_functions == []
    end

    test "lists [] proxy read only functions if no verified eip-1967 implementation" do
      token_contract_address = insert(:contract_address)

      insert(:smart_contract,
        address_hash: token_contract_address.hash,
        abi: [
          %{
            "type" => "function",
            "stateMutability" => "nonpayable",
            "payable" => false,
            "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
            "name" => "implementation",
            "inputs" => [],
            "constant" => false
          }
        ],
        contract_code_md5: "123"
      )

      blockchain_get_implementation_mock()

      path =
        smart_contract_path(BlockScoutWeb.Endpoint, :index,
          hash: token_contract_address.hash,
          type: :proxy,
          action: :read
        )

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert conn.status == 200
      assert conn.assigns.read_only_functions == []
    end

    test "lists [] proxy read only functions if no verified eip-1967 implementation and eth_getStorageAt returns not normalized address hash" do
      token_contract_address = insert(:contract_address)

      insert(:smart_contract,
        address_hash: token_contract_address.hash,
        abi: [
          %{
            "type" => "function",
            "stateMutability" => "nonpayable",
            "payable" => false,
            "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
            "name" => "implementation",
            "inputs" => [],
            "constant" => false
          }
        ],
        contract_code_md5: "123"
      )

      blockchain_get_implementation_mock_2()

      path =
        smart_contract_path(BlockScoutWeb.Endpoint, :index,
          hash: token_contract_address.hash,
          type: :proxy,
          action: :read
        )

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert conn.status == 200
      assert conn.assigns.read_only_functions == []
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
      smart_contract = insert(:smart_contract, contract_code_md5: "123")

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
      smart_contract = insert(:smart_contract, address_hash: address.hash, contract_code_md5: "123")

      blockchain_get_function_mock()

      path =
        smart_contract_path(
          BlockScoutWeb.Endpoint,
          :show,
          Address.checksum(smart_contract.address_hash),
          function_name: "get",
          method_id: "6d4ce63c",
          args_count: 0,
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
               outputs: [%{"type" => "uint256", "value" => 0}]
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

  defp blockchain_get_implementation_mock do
    EthereumJSONRPC.Mox
    |> TestHelper.mock_logic_storage_pointer_request(false, "0xcebb2CCCFe291F0c442841cBE9C1D06EED61Ca02")
  end

  defp blockchain_get_implementation_mock_2 do
    EthereumJSONRPC.Mox
    |> TestHelper.mock_logic_storage_pointer_request(
      false,
      "0x000000000000000000000000cebb2CCCFe291F0c442841cBE9C1D06EED61Ca02"
    )
  end
end
