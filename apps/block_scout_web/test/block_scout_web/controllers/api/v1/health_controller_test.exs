defmodule BlockScoutWeb.API.V1.HealthControllerTest do
  use BlockScoutWeb.ConnCase

  describe "GET last_block_status/0" do
    test "returns error when there are no blocks in db", %{conn: conn} do
      request = get(conn, api_v1_health_path(conn, :last_block_status))

      assert request.status == 500

      assert request.resp_body ==
               "{\"error_code\":5002,\"error_description\":\"There are no blocks in the DB\",\"error_title\":\"no blocks in db\",\"healthy\":false}"
    end

    test "returns error when last block is stale", %{conn: conn} do
      insert(:block, consensus: true, timestamp: Timex.shift(DateTime.utc_now(), hours: -50))

      request = get(conn, api_v1_health_path(conn, :last_block_status))

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
      insert(:block, consensus: true, timestamp: DateTime.utc_now())

      request = get(conn, api_v1_health_path(conn, :last_block_status))

      assert request.status == 200

      assert %{
               "healthy" => true,
               "data" => %{
                 "latest_block_number" => _,
                 "latest_block_inserted_at" => _
               }
             } = Poison.decode!(request.resp_body)
    end
  end
end
