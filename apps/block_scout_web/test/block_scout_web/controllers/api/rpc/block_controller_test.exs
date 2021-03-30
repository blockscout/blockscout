defmodule BlockScoutWeb.API.RPC.BlockControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Hash, Wei}
  alias BlockScoutWeb.Chain

  describe "getblockreward" do
    test "with missing block number", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "block", "action" => "getblockreward"})
        |> json_response(200)

      assert response["message"] =~ "'blockno' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = resolve_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid block number", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "block", "action" => "getblockreward", "blockno" => "badnumber"})
        |> json_response(200)

      assert response["message"] =~ "Invalid block number"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = resolve_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with a block that doesn't exist", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "block", "action" => "getblockreward", "blockno" => "42"})
        |> json_response(200)

      assert response["message"] =~ "Block does not exist"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = resolve_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with a valid block", %{conn: conn} do
      %{block_range: range} = emission_reward = insert(:emission_reward)
      block = insert(:block, number: Enum.random(Range.new(range.from, range.to)))

      :transaction
      |> insert(gas_price: 1)
      |> with_block(block, gas_used: 1)

      expected_reward =
        emission_reward.reward
        |> Wei.to(:wei)
        |> Decimal.add(Decimal.new(1))
        |> Decimal.to_string(:normal)

      expected_result = %{
        "blockNumber" => "#{block.number}",
        "timeStamp" => DateTime.to_unix(block.timestamp),
        "blockMiner" => Hash.to_string(block.miner_hash),
        "blockReward" => expected_reward,
        "uncles" => nil,
        "uncleInclusionReward" => nil
      }

      assert response =
               conn
               |> get("/api", %{"module" => "block", "action" => "getblockreward", "blockno" => "#{block.number}"})
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = resolve_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end
  end

  describe "getblocknobytime" do
    test "with missing timestamp param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "block", "action" => "getblocknobytime", "closest" => "after"})
        |> json_response(200)

      assert response["message"] =~ "Query parameter 'timestamp' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = resolve_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with missing closest param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "block", "action" => "getblocknobytime", "timestamp" => "1617019505"})
        |> json_response(200)

      assert response["message"] =~ "Query parameter 'closest' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = resolve_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid timestamp param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "block",
          "action" => "getblocknobytime",
          "timestamp" => "invalid",
          "closest" => " before"
        })
        |> json_response(200)

      assert response["message"] =~ "Invalid `timestamp` param"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = resolve_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid closest param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "block",
          "action" => "getblocknobytime",
          "timestamp" => "1617019505",
          "closest" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Invalid `closest` param"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = resolve_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid params and before", %{conn: conn} do
      timestamp_string = "1617020209"
      {:ok, timestamp} = Chain.param_to_block_timestamp(timestamp_string)
      block = insert(:block, timestamp: timestamp)

      {timestamp_int, _} = Integer.parse(timestamp_string)

      timestamp_in_the_future_str =
        (timestamp_int + 1)
        |> to_string()

      expected_result = %{
        "blockNumber" => "#{block.number}"
      }

      assert response =
               conn
               |> get("/api", %{
                 "module" => "block",
                 "action" => "getblocknobytime",
                 "timestamp" => "#{timestamp_in_the_future_str}",
                 "closest" => "before"
               })
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = resolve_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid params and after", %{conn: conn} do
      timestamp_string = "1617020209"
      {:ok, timestamp} = Chain.param_to_block_timestamp(timestamp_string)
      block = insert(:block, timestamp: timestamp)

      {timestamp_int, _} = Integer.parse(timestamp_string)

      timestamp_in_the_past_str =
        (timestamp_int - 1)
        |> to_string()

      expected_result = %{
        "blockNumber" => "#{block.number}"
      }

      assert response =
               conn
               |> get("/api", %{
                 "module" => "block",
                 "action" => "getblocknobytime",
                 "timestamp" => "#{timestamp_in_the_past_str}",
                 "closest" => "after"
               })
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = resolve_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end
  end

  defp resolve_schema() do
    ExJsonSchema.Schema.resolve(%{
      "type" => "object",
      "properties" => %{
        "message" => %{"type" => "string"},
        "status" => %{"type" => "string"},
        "result" => %{
          "type" => ["object", "null"],
          "properties" => %{
            "blockNumber" => %{"type" => "string"},
            "timeStamp" => %{"type" => "number"},
            "blockMiner" => %{"type" => "string"},
            "blockReward" => %{"type" => "string"},
            "uncles" => %{"type" => "null"},
            "uncleInclusionReward" => %{"type" => "null"}
          }
        }
      }
    })
  end
end
