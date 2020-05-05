defmodule BlockScoutWeb.API.RPC.BlockControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Hash, Wei}

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
