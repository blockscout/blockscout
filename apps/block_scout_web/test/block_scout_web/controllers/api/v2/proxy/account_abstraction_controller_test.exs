defmodule BlockScoutWeb.API.V2.Proxy.AccountAbstractionControllerTest do
  use BlockScoutWeb.ConnCase
  use EthereumJSONRPC.Case, async: false

  # Helper function to create complete user operation data
  defp create_user_op_data(operation_hash, block_hash, transaction_hash) do
    %{
      "hash" => operation_hash,
      "sender" => "0xc9f2b9AF320D92A7c9CD67BBbF0f3055F81B6d31",
      "nonce" => "0x000000000000000000000000000000000000000000000001000000000000042e",
      "call_data" =>
        "0xb61d27f600000000000000000000000047c4442562280196b54c640acd3af9f45c981f0c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000064541c9e4e00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020c5561301aaa52dbc9fdcbf9fdae2ea1a929207270c909f2b6248a3bc80b042b200000000000000000000000000000000000000000000000000000000",
      "call_gas_limit" => "633880",
      "verification_gas_limit" => "34721",
      "pre_verification_gas" => "48192",
      "max_fee_per_gas" => "220000000",
      "max_priority_fee_per_gas" => "2829647646",
      "signature" =>
        "0xff002c1dc16510d46e607fc4f05f0bb3fe73b1e8102b6b982fcfd2d0d1eed241d69206ffa9d4914417a679fbfe89b36259c7b96d7f84239e5037d9e8cc5456afab131c",
      "raw" => %{
        "nonce" => "18446744073709552686",
        "pre_verification_gas" => "48192",
        "paymaster_and_data" =>
          "0x2cc0c7981d846b9f2a16276556f6e8cb52bfb6330000000000000000000000000000788f00000000000000000000000000000000000000000000000068c81c5dc97f5c2402d4193ba68f29746742a77fad9571c3bb52056a877a98e369feab6c13f091314a3db58e01de16f79e459269577a54b17a7764f2728180b00d3a37281b",
        "signature" =>
          "0xff002c1dc16510d46e607fc4f05f0bb3fe73b1e8102b6b982fcfd2d0d1eed241d69206ffa9d4914417a679fbfe89b36259c7b96d7f84239e5037d9e8cc5456afab131c",
        "gas_fees" => "0x0000000000000000000000000d1cef00000000000000000000000000a8a8ff1e",
        "account_gas_limits" => "0x000000000000000000000000000087a10000000000000000000000000009ac18",
        "init_code" => "0x",
        "call_data" =>
          "0xb61d27f600000000000000000000000047c4442562280196b54c640acd3af9f45c981f0c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000064541c9e4e00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020c5561301aaa52dbc9fdcbf9fdae2ea1a929207270c909f2b6248a3bc80b042b200000000000000000000000000000000000000000000000000000000",
        "sender" => "0xc9f2b9AF320D92A7c9CD67BBbF0f3055F81B6d31"
      },
      "aggregator" => nil,
      "aggregator_signature" => nil,
      "entry_point" => "0x0000000071727De22E5E9d8BAf0edAc6f37da032",
      "entry_point_version" => "v0.7",
      "transaction_hash" => transaction_hash || "0xe0f96d979a2610a89a642744124e7caa087fe4771092286b763ea0d963a73fca",
      "block_number" => "9208931",
      "block_hash" => block_hash || "0xfe288e8d52d3148bda81194b9767e82d2238303a8808a1331b865cbb35f8bb35",
      "bundler" => "0x92613ef2DF071255D6ccd554651e7e445e939A32",
      "bundle_index" => 0,
      "index" => 0,
      "factory" => nil,
      "paymaster" => "0x2cc0c7981D846b9F2a16276556f6e8cb52BfB633",
      "status" => true,
      "revert_reason" => nil,
      "gas" => "747656",
      "gas_price" => "1067209413",
      "gas_used" => "416893",
      "sponsor_type" => "paymaster_sponsor",
      "user_logs_start_index" => 0,
      "user_logs_count" => 100,
      "fee" => "444912133813809",
      "consensus" => true,
      "timestamp" => "2025-09-15T13:52:12.000000Z",
      "execute_target" => "0x47C4442562280196b54c640acD3AF9F45c981F0C",
      "execute_call_data" =>
        "0x541c9e4e00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020c5561301aaa52dbc9fdcbf9fdae2ea1a929207270c909f2b6248a3bc80b042b2"
    }
  end

  describe "/proxy/account-abstraction/operations/{operation_hash}/summary?just_request_body=true" do
    setup do
      # Setup for TransactionInterpretation service
      original_ti_config =
        Application.get_env(:block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation)

      # Setup for AccountAbstraction service
      original_aa_config = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.AccountAbstraction)

      original_tesla_adapter = Application.get_env(:tesla, :adapter)
      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      aa_bypass = Bypass.open()
      ti_bypass = Bypass.open()

      on_exit(fn ->
        Application.put_env(
          :block_scout_web,
          BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
          original_ti_config
        )

        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.AccountAbstraction, original_aa_config)
        Application.put_env(:tesla, :adapter, original_tesla_adapter)

        Bypass.down(aa_bypass)
        Bypass.down(ti_bypass)
      end)

      # Return bypass instances for use in tests
      %{
        aa_bypass: aa_bypass,
        ti_bypass: ti_bypass
      }
    end

    test "return 422 on invalid operation hash", %{conn: conn} do
      request = get(conn, "/api/v2/proxy/account-abstraction/operations/0x/summary?just_request_body=true")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "return 404 on non existing operation", %{conn: conn, aa_bypass: aa_bypass, ti_bypass: ti_bypass} do
      operation_hash = "0x" <> String.duplicate("0", 64)

      # Setup AccountAbstraction service
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.AccountAbstraction,
        enabled: true,
        service_url: "http://localhost:#{aa_bypass.port}"
      )

      # Setup TransactionInterpretation service
      Application.put_env(:block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
        enabled: true,
        service_url: "http://localhost:#{ti_bypass.port}"
      )

      Bypass.expect_once(
        aa_bypass,
        "GET",
        "/api/v1/userOps/#{operation_hash}",
        fn conn ->
          Plug.Conn.resp(conn, 404, Jason.encode!(%{"error" => "Not found"}))
        end
      )

      request =
        get(conn, "/api/v2/proxy/account-abstraction/operations/#{operation_hash}/summary?just_request_body=true")

      assert %{"error" => "Not found"} = json_response(request, 404)
    end

    test "return request body for existing operation", %{conn: conn, aa_bypass: aa_bypass, ti_bypass: ti_bypass} do
      operation_hash = "0xcfb9123a6591d9f80ded2aec7e9842c2258c8e2a0d3c88f3a38a060aa10e9869"

      # Setup services
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.AccountAbstraction,
        enabled: true,
        service_url: "http://localhost:#{aa_bypass.port}"
      )

      Application.put_env(:block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
        enabled: true,
        service_url: "http://localhost:#{ti_bypass.port}"
      )

      transaction =
        :transaction
        |> insert()
        |> with_block()

      logs =
        insert_list(51, :token_transfer_log,
          transaction: transaction,
          block: transaction.block
        )

      for log <- logs do
        insert(:token_transfer_with_predefined_params,
          log: log,
          block: transaction.block
        )
      end

      user_op = create_user_op_data(operation_hash, transaction.block_hash, transaction.hash)

      Bypass.expect_once(
        aa_bypass,
        "GET",
        "/api/v1/userOps/#{operation_hash}",
        fn conn ->
          Plug.Conn.resp(conn, 200, Jason.encode!(user_op))
        end
      )

      request =
        get(conn, "/api/v2/proxy/account-abstraction/operations/#{operation_hash}/summary?just_request_body=true")

      assert response = json_response(request, 200)

      # Verify the structure of the request body
      assert Map.has_key?(response, "data")
      assert Map.has_key?(response, "logs_data")
      assert Map.has_key?(response, "chain_id")

      # Verify data structure
      data = response["data"]
      assert Map.has_key?(data, "to")
      assert Map.has_key?(data, "from")
      assert Map.has_key?(data, "hash")
      assert Map.has_key?(data, "type")
      assert Map.has_key?(data, "value")
      assert Map.has_key?(data, "method")
      assert Map.has_key?(data, "status")
      assert Map.has_key?(data, "transaction_types")
      assert Map.has_key?(data, "raw_input")
      assert Map.has_key?(data, "decoded_input")
      assert Map.has_key?(data, "token_transfers")

      # Verify logs_data structure
      logs_data = response["logs_data"]
      assert Map.has_key?(logs_data, "items")
      assert is_list(logs_data["items"])

      # Verify chain_id is present and is an integer
      assert is_integer(response["chain_id"])

      # Verify operation data matches
      assert operation_hash == data["hash"]
      assert 0 == data["type"]
      assert "0" == data["value"]
      assert true == data["status"]

      assert Enum.count(data["token_transfers"]) == 50
    end

    test "return 403 when transaction interpretation service is disabled", %{
      conn: conn,
      aa_bypass: aa_bypass
    } do
      operation_hash = "0xcfb9123a6591d9f80ded2aec7e9842c2258c8e2a0d3c88f3a38a060aa10e9869"

      # Setup AccountAbstraction service as enabled
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.AccountAbstraction,
        enabled: true,
        service_url: "http://localhost:#{aa_bypass.port}"
      )

      # Setup TransactionInterpretation service as disabled
      Application.put_env(:block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
        enabled: false
      )

      request =
        get(conn, "/api/v2/proxy/account-abstraction/operations/#{operation_hash}/summary?just_request_body=true")

      assert %{"message" => "Transaction Interpretation Service is disabled"} = json_response(request, 403)
    end
  end
end
