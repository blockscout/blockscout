defmodule BlockScoutWeb.API.V2.UtilsControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.TestHelper

  describe "/api/v2/utils/decode-calldata" do
    test "success decodes calldata", %{conn: conn} do
      transaction =
        :transaction_to_verified_contract
        |> insert()

      TestHelper.get_all_proxies_implementation_zero_addresses()

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

      TestHelper.get_all_proxies_implementation_zero_addresses()

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
end
