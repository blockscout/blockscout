defmodule ExplorerWeb.API.RPC.BlockControllerTest do
  use ExplorerWeb.ConnCase

  alias Explorer.Chain.{Hash, Wei}

  describe "getblockreward" do
    test "with missing block number", %{conn: conn} do
      assert response =
               conn
               |> get("/api", %{"module" => "block", "action" => "getblockreward"})
               |> json_response(400)

      assert response["message"] =~ "'blockno' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid block number", %{conn: conn} do
      assert response =
               conn
               |> get("/api", %{"module" => "block", "action" => "getblockreward", "blockno" => "badnumber"})
               |> json_response(400)

      assert response["message"] =~ "Invalid block number"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a block that doesn't exist", %{conn: conn} do
      assert response =
               conn
               |> get("/api", %{"module" => "block", "action" => "getblockreward", "blockno" => "42"})
               |> json_response(404)

      assert response["message"] =~ "Block does not exist"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a valid block", %{conn: conn} do
      %{block_range: range} = block_reward = insert(:block_reward)
      block = insert(:block, number: Enum.random(Range.new(range.from, range.to)))

      insert(
        :transaction,
        block: block,
        index: 0,
        gas_price: 1,
        receipt: build(:receipt, gas_used: 1, transaction_index: 0)
      )

      expected_reward =
        block_reward.reward
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
    end
  end
end
