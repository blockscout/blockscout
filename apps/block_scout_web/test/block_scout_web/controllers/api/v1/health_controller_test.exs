defmodule BlockScoutWeb.API.V1.HealthControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.{Chain, PagingOptions}

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())

    :ok
  end

  describe "GET last_block_status/0" do
    test "returns error when there are no blocks in db", %{conn: conn} do
      request = get(conn, api_v1_health_path(conn, :health))

      assert request.status == 500

      assert request.resp_body ==
               "{\"error_code\":5002,\"error_description\":\"There are no blocks in the DB\",\"error_title\":\"no blocks in db\",\"healthy\":false}"
    end

    test "returns error when last block is stale", %{conn: conn} do
      insert(:block, consensus: true, timestamp: Timex.shift(DateTime.utc_now(), hours: -50))

      request = get(conn, api_v1_health_path(conn, :health))

      assert request.status == 500

      assert %{
               "healthy" => false,
               "error_code" => 5001,
               "error_title" => "blocks fetching is stuck",
               "error_description" =>
                 "There are no new blocks in the DB for the last 5 mins. Check the healthiness of Ethereum archive node or the Blockscout DB instance",
               "data" => %{
                 "latest_block_number" => _,
                 "latest_block_inserted_at" => _
               }
             } = Poison.decode!(request.resp_body)
    end

    test "returns ok when last block is not stale", %{conn: conn} do
      block1 = insert(:block, consensus: true, timestamp: DateTime.utc_now(), number: 2)
      insert(:block, consensus: true, timestamp: DateTime.utc_now(), number: 1)

      request = get(conn, api_v1_health_path(conn, :health))

      assert request.status == 200

      result = Poison.decode!(request.resp_body)

      assert result["healthy"] == true

      assert %{
               "latest_block_number" => to_string(block1.number),
               "latest_block_inserted_at" => to_string(block1.timestamp),
               "cache_latest_block_number" => to_string(block1.number),
               "cache_latest_block_inserted_at" => to_string(block1.timestamp)
             } == result["data"]
    end
  end

  test "return error when cache is stale", %{conn: conn} do
    stale_block = insert(:block, consensus: true, timestamp: Timex.shift(DateTime.utc_now(), hours: -50), number: 3)
    state_block_hash = stale_block.hash

    assert [%{hash: ^state_block_hash}] = Chain.list_blocks(paging_options: %PagingOptions{page_size: 1})

    insert(:block, consensus: true, timestamp: DateTime.utc_now(), number: 1)

    assert [%{hash: ^state_block_hash}] = Chain.list_blocks(paging_options: %PagingOptions{page_size: 1})

    request = get(conn, api_v1_health_path(conn, :health))

    assert request.status == 500

    assert %{
             "healthy" => false,
             "error_code" => 5001,
             "error_title" => "blocks fetching is stuck",
             "error_description" =>
               "There are no new blocks in the DB for the last 5 mins. Check the healthiness of Ethereum archive node or the Blockscout DB instance",
             "data" => %{
               "latest_block_number" => _,
               "latest_block_inserted_at" => _
             }
           } = Poison.decode!(request.resp_body)
  end

  defp api_v1_health_path(conn, action) do
    "/api" <> ApiRoutes.api_v1_health_path(conn, action)
  end
end
