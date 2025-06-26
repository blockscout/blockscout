defmodule BlockScoutWeb.API.V1.HealthControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox
  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Cache.Blocks

  setup :set_mox_from_context

  setup do
    old_env = Application.get_env(:explorer, Explorer.Chain.Health.Monitor)
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Health.Monitor)
    Supervisor.terminate_child(Explorer.Supervisor, Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Blocks.child_id())

    new_env =
      old_env
      |> Keyword.replace(:check_interval, 100)

    Application.put_env(:explorer, Explorer.Chain.Health.Monitor, new_env)
    start_supervised!(Explorer.Chain.Health.Monitor)

    current_block_number = 100_500
    current_block_number_hex = integer_to_quantity(current_block_number)

    expect(EthereumJSONRPC.Mox, :json_rpc, fn %{method: "eth_blockNumber"}, _options ->
      {:ok, current_block_number_hex}
    end)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Chain.Health.Monitor, old_env)
    end)

    %{current_block_number: current_block_number}
  end

  describe "GET last_block_status/0" do
    test "returns error when there are no blocks in db", %{conn: conn} do
      request = get(conn, api_health_path(conn, :health))

      assert request.status == 500

      expected_error =
        %{
          "code" => 5002,
          "message" => "There are no blocks in the DB."
        }

      decoded_response = request.resp_body |> Jason.decode!()

      assert decoded_response["metadata"]["blocks"]["healthy"] == false
      assert decoded_response["metadata"]["blocks"]["error"] == expected_error
    end

    test "returns error when last block is stale", %{conn: conn, current_block_number: current_block_number} do
      block = insert(:block, consensus: true, timestamp: Timex.shift(DateTime.utc_now(), hours: -50))
      Blocks.update(block)

      :timer.sleep(150)

      request = get(conn, api_health_path(conn, :health))

      assert request.status == 500

      assert %{
               "latest_block" => %{
                 "cache" => %{
                   "number" => to_string(block.number),
                   "timestamp" => to_string(DateTime.truncate(block.timestamp, :second))
                 },
                 "db" => %{
                   "number" => to_string(block.number),
                   "timestamp" => to_string(DateTime.truncate(block.timestamp, :second))
                 },
                 "node" => %{"number" => to_string(current_block_number)}
               },
               "healthy" => false,
               "error" => %{
                 "code" => 5001,
                 "message" =>
                   "There are no new blocks in the DB for the last 3000 mins. Check the healthiness of the JSON RPC archive node or the DB."
               }
             } == Poison.decode!(request.resp_body)["metadata"]["blocks"]
    end

    test "returns ok when last block is not stale", %{conn: conn, current_block_number: current_block_number} do
      block1 = insert(:block, consensus: true, timestamp: DateTime.utc_now(), number: 2)
      Blocks.update(block1)
      block2 = insert(:block, consensus: true, timestamp: DateTime.utc_now(), number: 1)
      Blocks.update(block2)

      :timer.sleep(150)

      request = get(conn, api_health_path(conn, :health))

      result = Poison.decode!(request.resp_body)

      assert %{
               "latest_block" => %{
                 "db" => %{
                   "number" => to_string(block1.number),
                   "timestamp" => to_string(DateTime.truncate(block1.timestamp, :second))
                 },
                 "cache" => %{
                   "number" => to_string(block1.number),
                   "timestamp" => to_string(DateTime.truncate(block1.timestamp, :second))
                 },
                 "node" => %{"number" => to_string(current_block_number)}
               },
               "healthy" => true
             } == result["metadata"]["blocks"]
    end
  end

  test "return error when cache is stale", %{conn: conn, current_block_number: current_block_number} do
    stale_block = insert(:block, consensus: true, timestamp: Timex.shift(DateTime.utc_now(), hours: -50), number: 3)
    Blocks.update(stale_block)
    stale_block_hash = stale_block.hash

    assert [%{hash: ^stale_block_hash}] = Chain.list_blocks(paging_options: %PagingOptions{page_size: 1})

    block = insert(:block, consensus: true, timestamp: DateTime.utc_now(), number: 1)
    Blocks.update(block)

    assert [%{hash: ^stale_block_hash}] = Chain.list_blocks(paging_options: %PagingOptions{page_size: 1})

    :timer.sleep(150)

    request = get(conn, api_health_path(conn, :health))

    assert request.status == 500

    assert %{
             "latest_block" => %{
               "cache" => %{
                 "number" => to_string(stale_block.number),
                 "timestamp" => to_string(DateTime.truncate(stale_block.timestamp, :second))
               },
               "db" => %{
                 "number" => to_string(stale_block.number),
                 "timestamp" => to_string(DateTime.truncate(stale_block.timestamp, :second))
               },
               "node" => %{"number" => to_string(current_block_number)}
             },
             "healthy" => false,
             "error" => %{
               "code" => 5001,
               "message" =>
                 "There are no new blocks in the DB for the last 3000 mins. Check the healthiness of the JSON RPC archive node or the DB."
             }
           } == Poison.decode!(request.resp_body)["metadata"]["blocks"]
  end

  defp api_health_path(conn, action) do
    "/api" <> ApiRoutes.health_path(conn, action)
  end
end
