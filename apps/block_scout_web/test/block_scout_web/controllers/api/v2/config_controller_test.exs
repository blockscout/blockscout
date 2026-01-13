defmodule BlockScoutWeb.API.V2.ConfigControllerTest do
  use BlockScoutWeb.ConnCase

  @chain_type Application.compile_env(:explorer, :chain_type)

  describe "/config/backend" do
    test "returns chain_type when configured", %{conn: conn} do
      request = get(conn, "/api/v2/config/backend")
      response = json_response(request, 200)

      assert %{"chain_type" => chain_type} = response
      assert is_binary(chain_type)
    end

    test "returns the configured chain type value", %{conn: conn} do
      request = get(conn, "/api/v2/config/backend")
      response = json_response(request, 200)

      assert %{"chain_type" => chain_type} = response

      # Compare string representations
      expected_chain_type = if is_atom(@chain_type), do: Atom.to_string(@chain_type), else: @chain_type
      assert chain_type == expected_chain_type
    end
  end

  describe "/config/backend-version" do
    test "get json rps url if set", %{conn: conn} do
      version = "v6.3.0-beta"
      Application.put_env(:block_scout_web, :version, version)

      request = get(conn, "/api/v2/config/backend-version")

      assert %{"backend_version" => ^version} = json_response(request, 200)
    end

    test "get nil backend version if not set", %{conn: conn} do
      Application.put_env(:block_scout_web, :version, nil)

      request = get(conn, "/api/v2/config/backend-version")

      assert %{"backend_version" => nil} = json_response(request, 200)
    end
  end

  describe "/config/public-metrics" do
    test "returns configured update period hours", %{conn: conn} do
      # save existing configuration and set test value
      prev = Application.get_env(:explorer, Explorer.Chain.Metrics.PublicMetrics)
      Application.put_env(:explorer, Explorer.Chain.Metrics.PublicMetrics, update_period_hours: 7)

      on_exit(fn -> Application.put_env(:explorer, Explorer.Chain.Metrics.PublicMetrics, prev) end)

      request = get(conn, "/api/v2/config/public-metrics")
      assert %{"update_period_hours" => 7} = json_response(request, 200)
    end
  end

  describe "/config/smart-contracts/languages" do
    @base_languages ["solidity", "vyper", "yul", "geas"]

    case Application.compile_env(:explorer, :chain_type) do
      :arbitrum ->
        test "gets smart-contract languages", %{conn: conn} do
          request = get(conn, "/api/v2/config/smart-contracts/languages")
          response = json_response(request, 200)

          assert response == %{"languages" => @base_languages ++ ["stylus_rust"]}
        end

      :zilliqa ->
        test "gets smart-contract languages", %{conn: conn} do
          request = get(conn, "/api/v2/config/smart-contracts/languages")
          response = json_response(request, 200)

          assert response == %{"languages" => @base_languages ++ ["scilla"]}
        end

      _ ->
        test "gets smart-contract languages", %{conn: conn} do
          request = get(conn, "/api/v2/config/smart-contracts/languages")
          response = json_response(request, 200)

          assert response == %{"languages" => @base_languages}
        end
    end
  end

  describe "/config/db-background-migrations" do
    test "returns empty list when there are no uncompleted migrations", %{conn: conn} do
      request = get(conn, "/api/v2/config/db-background-migrations")
      assert %{"migrations" => migrations} = json_response(request, 200)
      assert is_list(migrations)
    end

    test "returns list of uncompleted migrations", %{conn: conn} do
      insert(:migration_status, migration_name: "test_migration", status: "started")

      request = get(conn, "/api/v2/config/db-background-migrations")
      assert %{"migrations" => migrations} = json_response(request, 200)

      assert Enum.any?(migrations, fn m -> m["migration_name"] == "test_migration" and m["status"] == "started" end)
    end

    test "does not return completed migrations", %{conn: conn} do
      insert(:migration_status, migration_name: "completed_migration", status: "completed")
      insert(:migration_status, migration_name: "started_migration", status: "started")

      request = get(conn, "/api/v2/config/db-background-migrations")
      assert %{"migrations" => migrations} = json_response(request, 200)

      assert Enum.all?(migrations, fn m -> m["status"] != "completed" end)
      assert Enum.any?(migrations, fn m -> m["migration_name"] == "started_migration" end)
    end

    test "returns migration with meta data", %{conn: conn} do
      insert(:migration_status,
        migration_name: "test_migration",
        status: "started",
        meta: %{"max_block_number" => 8_151_758}
      )

      request = get(conn, "/api/v2/config/db-background-migrations")
      assert %{"migrations" => migrations} = json_response(request, 200)

      migration = Enum.find(migrations, fn m -> m["migration_name"] == "test_migration" end)
      assert migration["meta"]["max_block_number"] == 8_151_758
    end

    test "returns migration timestamps", %{conn: conn} do
      insert(:migration_status, migration_name: "test_migration", status: "started")

      request = get(conn, "/api/v2/config/db-background-migrations")
      assert %{"migrations" => migrations} = json_response(request, 200)

      migration = Enum.find(migrations, fn m -> m["migration_name"] == "test_migration" end)
      assert Map.has_key?(migration, "inserted_at")
      assert Map.has_key?(migration, "updated_at")
    end
  end
end
