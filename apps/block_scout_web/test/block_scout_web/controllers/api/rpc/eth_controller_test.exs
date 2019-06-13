defmodule BlockScoutWeb.API.RPC.EthControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  alias Explorer.Counters.{AddressesWithBalanceCounter, AverageBlockTime}
  alias Indexer.Fetcher.CoinBalanceOnDemand

  setup do
    mocked_json_rpc_named_arguments = [
      transport: EthereumJSONRPC.Mox,
      transport_options: []
    ]

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    start_supervised!(AverageBlockTime)
    start_supervised!({CoinBalanceOnDemand, [mocked_json_rpc_named_arguments, [name: CoinBalanceOnDemand]]})
    start_supervised!(AddressesWithBalanceCounter)

    Application.put_env(:explorer, AverageBlockTime, enabled: true)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false)
    end)

    :ok
  end

  defp params(api_params, params), do: Map.put(api_params, "params", params)

  describe "eth_get_balance" do
    setup do
      %{
        api_params: %{
          "method" => "eth_getBalance",
          "jsonrpc" => "2.0",
          "id" => 0
        }
      }
    end

    test "with an invalid address", %{conn: conn, api_params: api_params} do
      assert response =
               conn
               |> post("/api/eth_rpc", params(api_params, ["badHash"]))
               |> json_response(200)

      assert %{"error" => "Query parameter 'address' is invalid"} = response
    end

    test "with a valid address that has no balance", %{conn: conn, api_params: api_params} do
      address = insert(:address)

      assert response =
               conn
               |> post("/api/eth_rpc", params(api_params, [to_string(address.hash)]))
               |> json_response(200)

      assert %{"error" => "Balance not found"} = response
    end

    test "with a valid address that has a balance", %{conn: conn, api_params: api_params} do
      block = insert(:block)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth_rpc", params(api_params, [to_string(address.hash)]))
               |> json_response(200)

      assert %{"result" => "0x1"} = response
    end

    test "with a valid address that has no earliest balance", %{conn: conn, api_params: api_params} do
      block = insert(:block, number: 1)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth_rpc", params(api_params, [to_string(address.hash), "earliest"]))
               |> json_response(200)

      assert response["error"] == "Balance not found"
    end

    test "with a valid address that has an earliest balance", %{conn: conn, api_params: api_params} do
      block = insert(:block, number: 0)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth_rpc", params(api_params, [to_string(address.hash), "earliest"]))
               |> json_response(200)

      assert response["result"] == "0x1"
    end

    test "with a valid address and no pending balance", %{conn: conn, api_params: api_params} do
      block = insert(:block, number: 1, consensus: true)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth_rpc", params(api_params, [to_string(address.hash), "pending"]))
               |> json_response(200)

      assert response["error"] == "Balance not found"
    end

    test "with a valid address and a pending balance", %{conn: conn, api_params: api_params} do
      block = insert(:block, number: 1, consensus: false)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth_rpc", params(api_params, [to_string(address.hash), "pending"]))
               |> json_response(200)

      assert response["result"] == "0x1"
    end

    test "with a valid address and a pending balance after a consensus block", %{conn: conn, api_params: api_params} do
      insert(:block, number: 1, consensus: true)
      block = insert(:block, number: 2, consensus: false)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth_rpc", params(api_params, [to_string(address.hash), "pending"]))
               |> json_response(200)

      assert response["result"] == "0x1"
    end

    test "with a block provided", %{conn: conn, api_params: api_params} do
      address = insert(:address)

      insert(:fetched_balance, block_number: 1, address_hash: address.hash, value: 1)
      insert(:fetched_balance, block_number: 2, address_hash: address.hash, value: 2)
      insert(:fetched_balance, block_number: 3, address_hash: address.hash, value: 3)

      assert response =
               conn
               |> post("/api/eth_rpc", params(api_params, [to_string(address.hash), "2"]))
               |> json_response(200)

      assert response["result"] == "0x2"
    end

    test "with a block provided and no balance", %{conn: conn, api_params: api_params} do
      address = insert(:address)

      insert(:fetched_balance, block_number: 3, address_hash: address.hash, value: 3)

      assert response =
               conn
               |> post("/api/eth_rpc", params(api_params, [to_string(address.hash), "2"]))
               |> json_response(200)

      assert response["error"] == "Balance not found"
    end

    test "with a batch of requests", %{conn: conn} do
      address = insert(:address)

      insert(:fetched_balance, block_number: 1, address_hash: address.hash, value: 1)
      insert(:fetched_balance, block_number: 2, address_hash: address.hash, value: 2)
      insert(:fetched_balance, block_number: 3, address_hash: address.hash, value: 3)

      params = [
        %{"id" => 0, "params" => [to_string(address.hash), "1"], "jsonrpc" => "2.0", "method" => "eth_getBalance"},
        %{"id" => 1, "params" => [to_string(address.hash), "2"], "jsonrpc" => "2.0", "method" => "eth_getBalance"},
        %{"id" => 2, "params" => [to_string(address.hash), "3"], "jsonrpc" => "2.0", "method" => "eth_getBalance"}
      ]

      assert response =
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/eth_rpc", Jason.encode!(params))
               |> json_response(200)

      assert [
               %{"id" => 0, "result" => "0x1"},
               %{"id" => 1, "result" => "0x2"},
               %{"id" => 2, "result" => "0x3"}
             ] = response
    end
  end
end
