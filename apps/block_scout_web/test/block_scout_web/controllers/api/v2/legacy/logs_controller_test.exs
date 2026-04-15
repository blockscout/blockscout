defmodule BlockScoutWeb.API.V2.Legacy.LogsControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.Transaction

  describe "GET /api/v2/legacy/logs/get-logs" do
    test "missing fromBlock, toBlock, address, and topic{x}", %{conn: conn} do
      response =
        conn
        |> get("/api/v2/legacy/logs/get-logs")
        |> json_response(200)

      assert response["status"] == "0"
      assert response["message"] =~ "Required query parameters missing"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "missing fromBlock", %{conn: conn} do
      response =
        conn
        |> get("/api/v2/legacy/logs/get-logs", %{
          "toBlock" => "10",
          "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["status"] == "0"
      assert response["message"] =~ "fromBlock"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "missing toBlock", %{conn: conn} do
      response =
        conn
        |> get("/api/v2/legacy/logs/get-logs", %{
          "fromBlock" => "5",
          "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["status"] == "0"
      assert response["message"] =~ "toBlock"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "missing address and topic{x}", %{conn: conn} do
      response =
        conn
        |> get("/api/v2/legacy/logs/get-logs", %{"fromBlock" => "5", "toBlock" => "10"})
        |> json_response(200)

      assert response["status"] == "0"
      assert response["message"] =~ "address and/or topic{x}"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "invalid fromBlock format", %{conn: conn} do
      response =
        conn
        |> get("/api/v2/legacy/logs/get-logs", %{
          "fromBlock" => "abc",
          "toBlock" => "10",
          "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["status"] == "0"
      assert response["message"] =~ "Invalid fromBlock format"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "no logs found returns empty result array", %{conn: conn} do
      response =
        conn
        |> get("/api/v2/legacy/logs/get-logs", %{
          "fromBlock" => "5",
          "toBlock" => "10",
          "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["status"] == "0"
      assert response["message"] == "No logs found"
      assert response["result"] == []
    end

    test "fromBlock=latest and toBlock=latest", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      insert(:log,
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number
      )

      response =
        conn
        |> get("/api/v2/legacy/logs/get-logs", %{
          "fromBlock" => "latest",
          "toBlock" => "latest",
          "address" => "#{contract_address.hash}"
        })
        |> json_response(200)

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert is_list(response["result"])
      assert length(response["result"]) == 1
    end

    test "success with logs returned", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log =
        insert(:log,
          address: contract_address,
          transaction: transaction,
          block: block,
          block_number: transaction.block_number
        )

      params = %{
        "fromBlock" => "#{block.number}",
        "toBlock" => "#{block.number}",
        "address" => "#{contract_address.hash}"
      }

      response =
        conn
        |> get("/api/v2/legacy/logs/get-logs", params)
        |> json_response(200)

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert [found_log] = response["result"]
      assert found_log["address"] == "#{contract_address.hash}"
      assert found_log["transactionHash"] == "#{transaction.hash}"
      assert found_log["blockNumber"] == integer_to_hex(log.block_number)
    end

    test "two topics set, required topicA_B_opr missing", %{conn: conn} do
      conditions = %{
        ["topic0", "topic1"] => "topic0_1_opr",
        ["topic0", "topic2"] => "topic0_2_opr",
        ["topic0", "topic3"] => "topic0_3_opr",
        ["topic1", "topic2"] => "topic1_2_opr",
        ["topic1", "topic3"] => "topic1_3_opr",
        ["topic2", "topic3"] => "topic2_3_opr"
      }

      for {[key1, key2], expectation} <- conditions do
        response =
          conn
          |> get("/api/v2/legacy/logs/get-logs", %{
            "fromBlock" => "5",
            "toBlock" => "10",
            key1 => "some topic",
            key2 => "some other topic"
          })
          |> json_response(200)

        assert response["status"] == "0"
        assert response["message"] == "Required query parameters missing: #{expectation}"
        assert Map.has_key?(response, "result")
        refute response["result"]
      end
    end

    test "four topics set, all six topic*_opr missing", %{conn: conn} do
      response =
        conn
        |> get("/api/v2/legacy/logs/get-logs", %{
          "fromBlock" => "5",
          "toBlock" => "10",
          "topic0" => "some topic",
          "topic1" => "some other topic",
          "topic2" => "some extra topic",
          "topic3" => "some different topic"
        })
        |> json_response(200)

      assert response["status"] == "0"

      assert response["message"] =~
               "Required query parameters missing: " <>
                 "topic0_1_opr, topic0_2_opr, topic0_3_opr, topic1_2_opr, topic1_3_opr, topic2_3_opr"

      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    # Parity invariant: response body must be byte-identical to the v1 endpoint.
    test "parity with v1 /api?module=logs&action=getLogs — success", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      insert(:log,
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: transaction.block_number
      )

      params = %{
        "fromBlock" => "#{block.number}",
        "toBlock" => "#{block.number}",
        "address" => "#{contract_address.hash}"
      }

      v1_response =
        conn
        |> get("/api", Map.merge(params, %{"module" => "logs", "action" => "getLogs"}))
        |> json_response(200)

      v2_response =
        conn
        |> get("/api/v2/legacy/logs/get-logs", params)
        |> json_response(200)

      assert v1_response == v2_response
    end

    test "parity with v1 /api?module=logs&action=getLogs — error (missing params)", %{conn: conn} do
      v1_response =
        conn
        |> get("/api", %{"module" => "logs", "action" => "getLogs"})
        |> json_response(200)

      v2_response =
        conn
        |> get("/api/v2/legacy/logs/get-logs")
        |> json_response(200)

      assert v1_response == v2_response
    end
  end

  defp integer_to_hex(integer), do: "0x" <> String.downcase(Integer.to_string(integer, 16))
end
