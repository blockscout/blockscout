defmodule BlockScoutWeb.API.V2.UtilsControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  describe "/api/v2/utils/decode-calldata" do
    test "success decodes calldata", %{conn: conn} do
      transaction =
        :transaction_to_verified_contract
        |> insert()

      request_zero_implementations()

      assert conn
             |> get("/api/v2/utils/decode-calldata", %{
               "calldata" => to_string(transaction.input),
               "address_hash" => to_string(transaction.to_address)
             })
             |> json_response(200) ==
               %{
                 "result" => %{
                   "method_call" => "set(uint256 x)",
                   "method_id" => "60fe47b1",
                   "parameters" => [%{"name" => "x", "type" => "uint256", "value" => "50"}]
                 }
               }

      request_zero_implementations()

      assert conn
             |> post("/api/v2/utils/decode-calldata", %{
               "calldata" => to_string(transaction.input),
               "address_hash" => to_string(transaction.to_address)
             })
             |> json_response(200) ==
               %{
                 "result" => %{
                   "method_call" => "set(uint256 x)",
                   "method_id" => "60fe47b1",
                   "parameters" => [%{"name" => "x", "type" => "uint256", "value" => "50"}]
                 }
               }
    end

    test "return nil in case of failed decoding", %{conn: conn} do
      assert conn
             |> post("/api/v2/utils/decode-calldata", %{
               "calldata" => "0x010101"
             })
             |> json_response(200) ==
               %{
                 "result" => nil
               }
    end

    test "decodes using ABI from smart_contracts_methods table", %{conn: conn} do
      insert(:contract_method)

      input_data =
        "set(uint)"
        |> ABI.encode([50])
        |> Base.encode16(case: :lower)

      assert conn
             |> post("/api/v2/utils/decode-calldata", %{
               "calldata" => "0x" <> input_data
             })
             |> json_response(200) ==
               %{
                 "result" => %{
                   "method_call" => "set(uint256 x)",
                   "method_id" => "60fe47b1",
                   "parameters" => [%{"name" => "x", "type" => "uint256", "value" => "50"}]
                 }
               }
    end
  end

  defp request_zero_implementations do
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
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3",
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
                                "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
  end
end
