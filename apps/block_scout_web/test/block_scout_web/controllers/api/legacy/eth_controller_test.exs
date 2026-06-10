# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.Legacy.EthControllerTest do
  @moduledoc """
  Tests for the JSON-RPC method republication endpoints under `/api/legacy/eth/*`.

  Parity claims against the v1 endpoint `/api/eth-rpc` are valid for
  single-request, non-batch inputs only. The legacy endpoints reject array
  bodies; the v1 endpoint dispatches batches.
  """

  use BlockScoutWeb.ConnCase, async: false

  import Mox

  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.{AddressesCount, AverageBlockTime}
  alias Explorer.Chain.Transaction

  setup do
    mocked_json_rpc_named_arguments = [
      transport: EthereumJSONRPC.Mox,
      transport_options: []
    ]

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    start_supervised!(AverageBlockTime)

    Indexer.Fetcher.OnDemand.CoinBalance.Supervisor.Case.start_supervised!(
      json_rpc_named_arguments: mocked_json_rpc_named_arguments
    )

    start_supervised!(AddressesCount)

    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

    :ok
  end

  defp jsonrpc_body(method, params, id \\ 0) do
    %{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}
  end

  defp post_json(conn, path, body) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(path, Utils.JSON.encode!(body))
  end

  describe "POST /api/legacy/eth/eth-get-balance" do
    test "with a valid address that has a balance", %{conn: conn} do
      block = insert(:block)
      address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: block.number)

      response =
        conn
        |> post("/api/legacy/eth/eth-get-balance", jsonrpc_body("eth_getBalance", [to_string(address.hash)]))
        |> json_response(200)

      assert response == %{"jsonrpc" => "2.0", "id" => 0, "result" => "0x1"}
    end

    test "with an invalid address — JSON-RPC error envelope", %{conn: conn} do
      response =
        conn
        |> post("/api/legacy/eth/eth-get-balance", jsonrpc_body("eth_getBalance", ["badHash"]))
        |> json_response(200)

      assert response == %{
               "jsonrpc" => "2.0",
               "id" => 0,
               "error" => %{"code" => -32602, "message" => "Query parameter 'address' is invalid"}
             }
    end

    test "method mismatch — returns JSON-RPC error envelope with same id", %{conn: conn} do
      response =
        conn
        |> post(
          "/api/legacy/eth/eth-get-balance",
          jsonrpc_body("eth_call", [%{"to" => "0x0000000000000000000000000000000000000000"}, "latest"], 42)
        )
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 42
      assert response["error"] =~ "must be `eth_getBalance`"
    end

    test "batch body rejected — JSON-RPC error envelope", %{conn: conn} do
      address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: 1)

      batch = [
        jsonrpc_body("eth_getBalance", [to_string(address.hash)], 0),
        jsonrpc_body("eth_getBalance", [to_string(address.hash)], 1)
      ]

      response =
        conn
        |> post_json("/api/legacy/eth/eth-get-balance", batch)
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["error"] =~ "Batch requests are not supported"
    end

    test "parity with v1 /api/eth-rpc — single-request success", %{conn: conn} do
      block = insert(:block)
      address = insert(:address, fetched_coin_balance: 1, fetched_coin_balance_block_number: block.number)

      body = jsonrpc_body("eth_getBalance", [to_string(address.hash)])

      v1_response =
        conn
        |> post("/api/eth-rpc", body)
        |> json_response(200)

      legacy_response =
        conn
        |> post("/api/legacy/eth/eth-get-balance", body)
        |> json_response(200)

      assert v1_response == legacy_response
    end

    test "parity with v1 /api/eth-rpc — single-request invalid address", %{conn: conn} do
      body = jsonrpc_body("eth_getBalance", ["badHash"])

      v1_response = conn |> post("/api/eth-rpc", body) |> json_response(200)
      legacy_response = conn |> post("/api/legacy/eth/eth-get-balance", body) |> json_response(200)

      assert v1_response == legacy_response
    end
  end

  # The remaining three methods are proxy methods — they short-circuit on
  # parameter validation before any upstream JSON-RPC call. We exercise the
  # wrapper-specific behaviors (method match, batch rejection, validation
  # error envelope shape) without standing up a JSON-RPC node.

  describe "POST /api/legacy/eth/eth-call" do
    test "success — forwards to JSON-RPC node and returns the result", %{conn: conn} do
      to_address = "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F"
      input = "0xd4aae0c4"
      result_hex = "0x0000000000000000000000001dd91b354ebd706ab3ac7c727455c7baa164945a"

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               jsonrpc: "2.0",
               id: 0,
               method: "eth_call",
               params: [%{"to" => ^to_address, "input" => ^input}, "latest"]
             }
           ],
           _options ->
          {:ok, [%{id: 0, jsonrpc: "2.0", result: result_hex}]}
        end
      )

      response =
        conn
        |> post(
          "/api/legacy/eth/eth-call",
          jsonrpc_body("eth_call", [%{"to" => to_address, "input" => input}, "latest"])
        )
        |> json_response(200)

      assert response == %{"jsonrpc" => "2.0", "id" => 0, "result" => result_hex}
    end

    test "success — forwards all documented call-object fields to JSON-RPC node", %{conn: conn} do
      to_address = "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F"
      from_address = "0x0000000000000000000000000000000000000007"
      gas = "0x5208"
      gas_price = "0x3b9aca00"
      value = "0x0"
      input = "0xd4aae0c4"
      result_hex = "0x0000000000000000000000001dd91b354ebd706ab3ac7c727455c7baa164945a"

      call_object = %{
        "to" => to_address,
        "from" => from_address,
        "gas" => gas,
        "gasPrice" => gas_price,
        "value" => value,
        "input" => input
      }

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               jsonrpc: "2.0",
               id: 0,
               method: "eth_call",
               params: [
                 %{
                   "to" => ^to_address,
                   "from" => ^from_address,
                   "gas" => ^gas,
                   "gasPrice" => ^gas_price,
                   "value" => ^value,
                   "input" => ^input
                 },
                 "latest"
               ]
             }
           ],
           _options ->
          {:ok, [%{id: 0, jsonrpc: "2.0", result: result_hex}]}
        end
      )

      response =
        conn
        |> post(
          "/api/legacy/eth/eth-call",
          jsonrpc_body("eth_call", [call_object, "latest"])
        )
        |> json_response(200)

      assert response == %{"jsonrpc" => "2.0", "id" => 0, "result" => result_hex}
    end

    test "method mismatch — JSON-RPC error envelope", %{conn: conn} do
      response =
        conn
        |> post(
          "/api/legacy/eth/eth-call",
          jsonrpc_body("eth_chainId", [], 1)
        )
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert response["error"] =~ "must be `eth_call`"
    end

    test "missing required `to` in eth_call object — validation error envelope", %{conn: conn} do
      response =
        conn
        |> post(
          "/api/legacy/eth/eth-call",
          jsonrpc_body("eth_call", [%{"from" => "0x0000000000000000000000000000000000000001"}, "latest"], 2)
        )
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 2
      assert response["error"]["code"] == -32602
      assert response["error"]["message"] =~ ~r/Missed.*to.*address/i
    end

    test "batch body rejected", %{conn: conn} do
      batch = [jsonrpc_body("eth_call", [%{"to" => "0x0000000000000000000000000000000000000000"}, "latest"], 0)]

      response =
        conn
        |> post_json("/api/legacy/eth/eth-call", batch)
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["error"] =~ "Batch requests are not supported"
    end
  end

  describe "POST /api/legacy/eth/eth-get-storage-at" do
    test "success — forwards to JSON-RPC node and returns the result", %{conn: conn} do
      address = "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F"
      slot = "0x0"
      result_hex = "0x0000000000000000000000000000000000000000000000000000000000000000"

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{jsonrpc: "2.0", id: 4, method: "eth_getStorageAt", params: [^address, ^slot, "latest"]}], _options ->
          {:ok, [%{id: 4, jsonrpc: "2.0", result: result_hex}]}
        end
      )

      response =
        conn
        |> post(
          "/api/legacy/eth/eth-get-storage-at",
          jsonrpc_body("eth_getStorageAt", [address, slot, "latest"], 4)
        )
        |> json_response(200)

      assert response == %{"jsonrpc" => "2.0", "id" => 4, "result" => result_hex}
    end

    test "method mismatch — JSON-RPC error envelope", %{conn: conn} do
      response =
        conn
        |> post("/api/legacy/eth/eth-get-storage-at", jsonrpc_body("eth_blockNumber", [], 3))
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 3
      assert response["error"] =~ "must be `eth_getStorageAt`"
    end

    test "invalid address — validation error envelope", %{conn: conn} do
      response =
        conn
        |> post(
          "/api/legacy/eth/eth-get-storage-at",
          jsonrpc_body("eth_getStorageAt", ["badHash", "0x0", "latest"], 4)
        )
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 4
      assert response["error"]["code"] == -32602
      assert response["error"]["message"] =~ "Invalid address"
    end

    test "batch body rejected", %{conn: conn} do
      batch = [
        jsonrpc_body("eth_getStorageAt", ["0x0000000000000000000000000000000000000000", "0x0", "latest"], 0)
      ]

      response =
        conn
        |> post_json("/api/legacy/eth/eth-get-storage-at", batch)
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["error"] =~ "Batch requests are not supported"
    end

    test "parity with v1 /api/eth-rpc — single-request success", %{conn: conn} do
      address = "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F"
      slot = "0x0"
      result_hex = "0x0000000000000000000000000000000000000000000000000000000000000000"

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        2,
        fn [%{jsonrpc: "2.0", method: "eth_getStorageAt", params: [^address, ^slot, "latest"]}], _options ->
          {:ok, [%{id: 0, jsonrpc: "2.0", result: result_hex}]}
        end
      )

      body = jsonrpc_body("eth_getStorageAt", [address, slot, "latest"])

      v1_response = conn |> post("/api/eth-rpc", body) |> json_response(200)
      legacy_response = conn |> post("/api/legacy/eth/eth-get-storage-at", body) |> json_response(200)

      assert v1_response == legacy_response
    end

    test "parity with v1 /api/eth-rpc — single-request invalid address", %{conn: conn} do
      body = jsonrpc_body("eth_getStorageAt", ["badHash", "0x0", "latest"])

      v1_response = conn |> post("/api/eth-rpc", body) |> json_response(200)
      legacy_response = conn |> post("/api/legacy/eth/eth-get-storage-at", body) |> json_response(200)

      assert v1_response == legacy_response
    end
  end

  describe "POST /api/legacy/eth/eth-send-raw-transaction" do
    test "success — forwards signed transaction to JSON-RPC node and returns the hash", %{conn: conn} do
      raw_tx = "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
      tx_hash = "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331e"

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{jsonrpc: "2.0", id: 0, method: "eth_sendRawTransaction", params: [^raw_tx]}], _options ->
          {:ok, [%{id: 0, jsonrpc: "2.0", result: tx_hash}]}
        end
      )

      response =
        conn
        |> post(
          "/api/legacy/eth/eth-send-raw-transaction",
          jsonrpc_body("eth_sendRawTransaction", [raw_tx])
        )
        |> json_response(200)

      assert response == %{"jsonrpc" => "2.0", "id" => 0, "result" => tx_hash}
    end

    test "method mismatch — JSON-RPC error envelope", %{conn: conn} do
      response =
        conn
        |> post("/api/legacy/eth/eth-send-raw-transaction", jsonrpc_body("eth_blockNumber", [], "abc"))
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == "abc"
      assert response["error"] =~ "must be `eth_sendRawTransaction`"
    end

    test "invalid raw transaction hex — validation error envelope", %{conn: conn} do
      response =
        conn
        |> post(
          "/api/legacy/eth/eth-send-raw-transaction",
          jsonrpc_body("eth_sendRawTransaction", ["not-hex"], 5)
        )
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 5
      assert response["error"]["code"] == -32602
      assert response["error"]["message"] =~ "Invalid hex data"
    end

    test "batch body rejected", %{conn: conn} do
      batch = [jsonrpc_body("eth_sendRawTransaction", ["0xdead"], 0)]

      response =
        conn
        |> post_json("/api/legacy/eth/eth-send-raw-transaction", batch)
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["error"] =~ "Batch requests are not supported"
    end
  end

  describe "POST /api/legacy/eth/eth-block-number" do
    setup do
      Supervisor.terminate_child(Explorer.Supervisor, BlockNumber.child_id())
      Supervisor.restart_child(Explorer.Supervisor, BlockNumber.child_id())
      :ok
    end

    test "returns hex-encoded latest block number", %{conn: conn} do
      insert(:block)

      response =
        conn
        |> post_json("/api/legacy/eth/eth-block-number", %{"jsonrpc" => "2.0", "method" => "eth_blockNumber", "id" => 1})
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert is_binary(response["result"])
      assert String.starts_with?(response["result"], "0x")
    end

    test "empty database — result is \"0x0\"", %{conn: conn} do
      response =
        conn
        |> post_json("/api/legacy/eth/eth-block-number", %{"jsonrpc" => "2.0", "method" => "eth_blockNumber", "id" => 1})
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["result"] == "0x0"
    end

    test "method mismatch — JSON-RPC error envelope", %{conn: conn} do
      response =
        conn
        |> post_json("/api/legacy/eth/eth-block-number", jsonrpc_body("eth_chainId", [], 7))
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 7
      assert response["error"] =~ "must be `eth_blockNumber`"
    end

    test "batch body rejected — JSON-RPC error envelope", %{conn: conn} do
      batch = [%{"jsonrpc" => "2.0", "method" => "eth_blockNumber", "id" => 0}]

      response =
        conn
        |> post_json("/api/legacy/eth/eth-block-number", batch)
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["error"] =~ "Batch requests are not supported"
    end

    test "parity with v1 /api/eth-rpc", %{conn: conn} do
      insert(:block)

      body = %{"jsonrpc" => "2.0", "method" => "eth_blockNumber", "id" => 1}

      v1_response = conn |> post("/api/eth-rpc", body) |> json_response(200)
      legacy_response = conn |> post_json("/api/legacy/eth/eth-block-number", body) |> json_response(200)

      assert v1_response == legacy_response
    end
  end

  describe "POST /api/legacy/eth/eth-get-logs" do
    test "method mismatch — JSON-RPC error envelope", %{conn: conn} do
      response =
        conn
        |> post(
          "/api/legacy/eth/eth-get-logs",
          jsonrpc_body("eth_getBalance", ["0x0000000000000000000000000000000000000001"], 3)
        )
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 3
      assert response["error"] =~ "must be `eth_getLogs`"
    end

    test "batch body rejected — JSON-RPC error envelope", %{conn: conn} do
      filter = %{"fromBlock" => "0x1", "toBlock" => "0xa"}
      batch = [jsonrpc_body("eth_getLogs", [filter], 0)]

      response =
        conn
        |> post_json("/api/legacy/eth/eth-get-logs", batch)
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["error"] =~ "Batch requests are not supported"
    end

    test "success — returns logs matching filter in JSON-RPC 2.0 format", %{conn: conn} do
      contract_address = insert(:contract_address)

      %Transaction{block: block} =
        transaction =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      insert(:log,
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number
      )

      filter = %{
        "fromBlock" => "0x" <> Integer.to_string(block.number, 16),
        "toBlock" => "0x" <> Integer.to_string(block.number, 16),
        "address" => to_string(contract_address.hash)
      }

      response =
        conn
        |> post("/api/legacy/eth/eth-get-logs", jsonrpc_body("eth_getLogs", [filter], 1))
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert is_list(response["result"])
      assert length(response["result"]) == 1
      [log_entry] = response["result"]
      assert log_entry["address"] == to_string(contract_address.hash)
      assert log_entry["transactionHash"] == to_string(transaction.hash)
      assert Map.has_key?(log_entry, "blockHash")
      assert Map.has_key?(log_entry, "removed")
    end

    test "parity with v1 /api/eth-rpc — filter with no results", %{conn: conn} do
      filter = %{"fromBlock" => "0x1", "toBlock" => "0xa", "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"}
      body = jsonrpc_body("eth_getLogs", [filter], 0)

      v1_response = conn |> post("/api/eth-rpc", body) |> json_response(200)
      legacy_response = conn |> post("/api/legacy/eth/eth-get-logs", body) |> json_response(200)

      assert v1_response == legacy_response
    end
  end
end
