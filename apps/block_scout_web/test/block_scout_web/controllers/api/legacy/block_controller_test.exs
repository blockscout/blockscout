defmodule BlockScoutWeb.API.Legacy.BlockControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Chain
  alias Explorer.Chain.Cache.BlockNumber

  describe "GET /api/legacy/block/get-block-number-by-time" do
    test "missing timestamp param", %{conn: conn} do
      response =
        conn
        |> get("/api/legacy/block/get-block-number-by-time", %{"closest" => "after"})
        |> json_response(200)

      assert response["status"] == "0"
      assert response["message"] =~ "Query parameter 'timestamp' is required"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "missing closest param", %{conn: conn} do
      response =
        conn
        |> get("/api/legacy/block/get-block-number-by-time", %{"timestamp" => "1617019505"})
        |> json_response(200)

      assert response["status"] == "0"
      assert response["message"] =~ "Query parameter 'closest' is required"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "invalid timestamp param", %{conn: conn} do
      response =
        conn
        |> get("/api/legacy/block/get-block-number-by-time", %{
          "timestamp" => "invalid",
          "closest" => "before"
        })
        |> json_response(200)

      assert response["status"] == "0"
      assert response["message"] =~ "Invalid `timestamp` param"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "invalid closest param", %{conn: conn} do
      response =
        conn
        |> get("/api/legacy/block/get-block-number-by-time", %{
          "timestamp" => "1617019505",
          "closest" => "invalid"
        })
        |> json_response(200)

      assert response["status"] == "0"
      assert response["message"] =~ "Invalid `closest` param"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "not found — no matching block", %{conn: conn} do
      response =
        conn
        |> get("/api/legacy/block/get-block-number-by-time", %{
          "timestamp" => "1617019505",
          "closest" => "before"
        })
        |> json_response(200)

      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "success with closest=before", %{conn: conn} do
      timestamp_string = "1617020209"
      {:ok, timestamp} = Chain.param_to_block_timestamp(timestamp_string)
      block = insert(:block, timestamp: timestamp)

      {timestamp_int, _} = Integer.parse(timestamp_string)
      timestamp_in_the_future = to_string(timestamp_int + 1)

      response =
        conn
        |> get("/api/legacy/block/get-block-number-by-time", %{
          "timestamp" => timestamp_in_the_future,
          "closest" => "before"
        })
        |> json_response(200)

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert response["result"] == %{"blockNumber" => "#{block.number}"}
    end

    test "success with closest=after", %{conn: conn} do
      timestamp_string = "1617020209"
      {:ok, timestamp} = Chain.param_to_block_timestamp(timestamp_string)
      block = insert(:block, timestamp: timestamp)

      {timestamp_int, _} = Integer.parse(timestamp_string)
      timestamp_in_the_past = to_string(timestamp_int - 1)

      response =
        conn
        |> get("/api/legacy/block/get-block-number-by-time", %{
          "timestamp" => timestamp_in_the_past,
          "closest" => "after"
        })
        |> json_response(200)

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert response["result"] == %{"blockNumber" => "#{block.number}"}
    end

    # Parity invariant: response body must be byte-identical to the v1 endpoint.
    test "parity with v1 /api?module=block&action=getblocknobytime — success", %{conn: conn} do
      timestamp_string = "1617020209"
      {:ok, timestamp} = Chain.param_to_block_timestamp(timestamp_string)
      insert(:block, timestamp: timestamp)

      {timestamp_int, _} = Integer.parse(timestamp_string)
      timestamp_in_the_future = to_string(timestamp_int + 1)

      params = %{"timestamp" => timestamp_in_the_future, "closest" => "before"}

      v1_response =
        conn
        |> get("/api", Map.merge(params, %{"module" => "block", "action" => "getblocknobytime"}))
        |> json_response(200)

      v2_response =
        conn
        |> get("/api/legacy/block/get-block-number-by-time", params)
        |> json_response(200)

      assert v1_response == v2_response
    end

    test "parity with v1 /api?module=block&action=getblocknobytime — error (missing params)", %{conn: conn} do
      v1_response =
        conn
        |> get("/api", %{"module" => "block", "action" => "getblocknobytime"})
        |> json_response(200)

      v2_response =
        conn
        |> get("/api/legacy/block/get-block-number-by-time")
        |> json_response(200)

      assert v1_response == v2_response
    end
  end

  describe "GET /api/legacy/block/eth-block-number" do
    setup do
      Supervisor.terminate_child(Explorer.Supervisor, BlockNumber.child_id())
      Supervisor.restart_child(Explorer.Supervisor, BlockNumber.child_id())
      :ok
    end

    test "default id (omitted) — returns integer id 1", %{conn: conn} do
      insert(:block)

      response =
        conn
        |> get("/api/legacy/block/eth-block-number")
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert is_binary(response["result"])
      assert String.starts_with?(response["result"], "0x")
      # When id is omitted the v1 controller defaults to integer 1
      assert response["id"] == 1
    end

    test "integer id (?id=7) — echoed back as string (query strings are strings)", %{conn: conn} do
      insert(:block)

      response =
        conn
        |> get("/api/legacy/block/eth-block-number", %{"id" => "7"})
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert is_binary(response["result"])
      # id=7 comes in as the string "7"; sanitize_id emits it quoted → "7"
      assert response["id"] == "7"
    end

    test "string id (?id=hello) — echoed back as string", %{conn: conn} do
      insert(:block)

      response =
        conn
        |> get("/api/legacy/block/eth-block-number", %{"id" => "hello"})
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == "hello"
    end

    test "empty database — result is \"0x0\"", %{conn: conn} do
      # No blocks inserted. BlockNumber.get_max/0 delegates to
      # Block.fetch_max_block_number/0 which returns Repo.one(query) || 0, so the
      # result is 0, not nil. encode_quantity(0) → "0x0".
      response =
        conn
        |> get("/api/legacy/block/eth-block-number")
        |> json_response(200)

      assert response["jsonrpc"] == "2.0"
      assert response["result"] == "0x0"
    end

    # Parity invariant: response body must be byte-identical to the v1 endpoint.
    test "parity with v1 /api?module=block&action=eth_block_number — default id", %{conn: conn} do
      insert(:block)

      v1_response =
        conn
        |> get("/api", %{"module" => "block", "action" => "eth_block_number"})
        |> json_response(200)

      v2_response =
        conn
        |> get("/api/legacy/block/eth-block-number")
        |> json_response(200)

      assert v1_response == v2_response
    end

    test "parity with v1 /api?module=block&action=eth_block_number — empty database", %{conn: conn} do
      v1_response =
        conn
        |> get("/api", %{"module" => "block", "action" => "eth_block_number"})
        |> json_response(200)

      v2_response =
        conn
        |> get("/api/legacy/block/eth-block-number")
        |> json_response(200)

      assert v1_response == v2_response
    end
  end
end
