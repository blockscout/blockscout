defmodule BlockScoutWeb.API.RPC.BlockControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Chain
  alias Explorer.Chain.{Hash, Wei}
  alias Explorer.Chain.Cache.Counters.AverageBlockTime

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
      schema = resolve_getblockreward_schema()
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
      schema = resolve_getblockreward_schema()
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
      schema = resolve_getblockreward_schema()
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

      insert(:reward, address_hash: block.miner_hash, block_hash: block.hash, reward: expected_reward)

      expected_result = %{
        "blockNumber" => "#{block.number}",
        "timeStamp" => DateTime.to_unix(block.timestamp),
        "blockMiner" => Hash.to_string(block.miner_hash),
        "blockReward" => expected_reward |> Decimal.to_string(:normal),
        "uncles" => [],
        "uncleInclusionReward" => "0"
      }

      assert response =
               conn
               |> get("/api", %{"module" => "block", "action" => "getblockreward", "blockno" => "#{block.number}"})
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = resolve_getblockreward_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with a valid block and uncles", %{conn: conn} do
      %{block_range: range} = emission_reward = insert(:emission_reward)
      block = insert(:block, number: Enum.random(Range.new(range.from + 2, range.to)))
      uncle1 = insert(:block, number: block.number - 1)
      uncle2 = insert(:block, number: block.number - 2)

      insert(:block_second_degree_relation, nephew: block, uncle_hash: uncle1.hash, index: 0)
      insert(:block_second_degree_relation, nephew: block, uncle_hash: uncle2.hash, index: 1)

      :transaction
      |> insert(gas_price: 1)
      |> with_block(block, gas_used: 1)

      decimal_emission_reward = Wei.to(emission_reward.reward, :wei)

      uncle1_reward =
        decimal_emission_reward |> Decimal.div(8) |> Decimal.mult(Decimal.new(uncle1.number + 8 - block.number))

      uncle2_reward =
        decimal_emission_reward |> Decimal.div(8) |> Decimal.mult(Decimal.new(uncle2.number + 8 - block.number))

      uncle_inclusion_reward =
        decimal_emission_reward
        |> Decimal.div(Decimal.new(32))
        |> Decimal.mult(Decimal.new(2))

      block_reward =
        decimal_emission_reward
        |> Decimal.add(Decimal.new(1))
        |> Decimal.add(uncle_inclusion_reward)

      insert(:reward, address_hash: block.miner_hash, block_hash: block.hash, reward: block_reward)

      insert(:reward,
        address_hash: uncle1.miner_hash,
        block_hash: block.hash,
        reward: uncle1_reward,
        address_type: :uncle
      )

      insert(:reward,
        address_hash: uncle2.miner_hash,
        block_hash: block.hash,
        reward: uncle2_reward,
        address_type: :uncle
      )

      expected_result = %{
        "blockNumber" => "#{block.number}",
        "timeStamp" => DateTime.to_unix(block.timestamp),
        "blockMiner" => Hash.to_string(block.miner_hash),
        "blockReward" => block_reward |> Decimal.to_string(:normal),
        "uncles" => [
          %{
            "blockreward" => uncle1_reward |> Decimal.to_string(:normal),
            "miner" => uncle1.miner_hash |> Hash.to_string(),
            "unclePosition" => "0"
          },
          %{
            "blockreward" => uncle2_reward |> Decimal.to_string(:normal),
            "miner" => uncle2.miner_hash |> Hash.to_string(),
            "unclePosition" => "1"
          }
        ],
        "uncleInclusionReward" => "0"
      }

      assert response =
               conn
               |> get("/api", %{"module" => "block", "action" => "getblockreward", "blockno" => "#{block.number}"})
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = resolve_getblockreward_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end
  end

  describe "getblockcountdown" do
    setup do
      start_supervised!(AverageBlockTime)
      Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

      on_exit(fn ->
        Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
      end)
    end

    test "returns countdown information when valid block number is provided", %{conn: conn} do
      unsafe_target_block_number = "120"
      current_block_number = 110
      average_block_time = 15
      remaining_blocks = 10

      first_timestamp = Timex.now()

      for i <- 1..current_block_number do
        insert(:block, number: i, timestamp: Timex.shift(first_timestamp, seconds: i * average_block_time))
      end

      AverageBlockTime.refresh()

      estimated_time_in_sec = Float.round(remaining_blocks * average_block_time * 1.0, 1)

      expected_result = %{
        "CurrentBlock" => "#{current_block_number}",
        "CountdownBlock" => unsafe_target_block_number,
        "RemainingBlock" => "#{remaining_blocks}",
        "EstimateTimeInSec" => "#{estimated_time_in_sec}"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "block",
          "action" => "getblockcountdown",
          "blockno" => unsafe_target_block_number
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = resolve_getblockcountdown_schema()
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
      schema = resolve_getblocknobytime_schema()
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
      schema = resolve_getblocknobytime_schema()
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
      schema = resolve_getblocknobytime_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an excessively large timestamp param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "block",
          "action" => "getblocknobytime",
          "timestamp" => "1000000000000000000000000",
          "closest" => "before"
        })
        |> json_response(200)

      assert response["message"] =~ "Invalid `timestamp` param"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = resolve_getblocknobytime_schema()
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
      schema = resolve_getblocknobytime_schema()
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

      assert response =
               conn
               |> get("/api", %{
                 "module" => "block",
                 "action" => "getblocknobytime",
                 "timestamp" => "#{timestamp_in_the_future_str}",
                 "closest" => "before"
               })
               |> json_response(200)

      assert response["result"] == "#{block.number}"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = resolve_getblocknobytime_schema()
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

      assert response =
               conn
               |> get("/api", %{
                 "module" => "block",
                 "action" => "getblocknobytime",
                 "timestamp" => "#{timestamp_in_the_past_str}",
                 "closest" => "after"
               })
               |> json_response(200)

      assert response["result"] == "#{block.number}"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = resolve_getblocknobytime_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "returns any nearest block within arbitrary range of time", %{conn: conn} do
      timestamp_string = "1617020209"
      {:ok, timestamp} = Chain.param_to_block_timestamp(timestamp_string)
      block = insert(:block, timestamp: timestamp)

      {timestamp_int, _} = Integer.parse(timestamp_string)

      timestamp_in_the_past_str =
        (timestamp_int - 2 * 60)
        |> to_string()

      assert response =
               conn
               |> get("/api", %{
                 "module" => "block",
                 "action" => "getblocknobytime",
                 "timestamp" => "#{timestamp_in_the_past_str}",
                 "closest" => "after"
               })
               |> json_response(200)

      assert response["result"] == "#{block.number}"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = resolve_getblocknobytime_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end
  end

  defp resolve_getblockreward_schema() do
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
            "uncles" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "properties" => %{
                  "miner" => %{"type" => "string"},
                  "unclePosition" => %{"type" => "string"},
                  "blockreward" => %{"type" => "string"}
                }
              }
            },
            "uncleInclusionReward" => %{"type" => "string"}
          }
        }
      }
    })
  end

  defp resolve_getblockcountdown_schema() do
    ExJsonSchema.Schema.resolve(%{
      "type" => "object",
      "properties" => %{
        "message" => %{"type" => "string"},
        "status" => %{"type" => "string"},
        "result" => %{
          "type" => "object",
          "properties" => %{
            "CurrentBlock" => %{"type" => "string"},
            "CountdownBlock" => %{"type" => "string"},
            "RemainingBlock" => %{"type" => "string"},
            "EstimateTimeInSec" => %{"type" => "string"}
          }
        }
      }
    })
  end

  defp resolve_getblocknobytime_schema do
    ExJsonSchema.Schema.resolve(%{
      "type" => "object",
      "properties" => %{
        "message" => %{"type" => "string"},
        "status" => %{"type" => "string"},
        "result" => %{
          "type" => ["string", "null"],
          "description" => "Block number as a string or null if not found"
        }
      }
    })
  end
end
