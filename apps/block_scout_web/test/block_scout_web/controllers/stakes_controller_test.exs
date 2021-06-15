defmodule BlockScoutWeb.StakesControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Counters.AverageBlockTime

  setup do
    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false)
    end)
  end

  describe "GET validators/2" do
    test "returns page", %{conn: conn} do
      conn = get(conn, validators_path(conn, :index))
      assert conn.status == 200
    end

    test "returns rendered table", %{conn: conn} do
      pools = Enum.map(1..4, fn _ -> insert(:staking_pool) end)

      conn = get(conn, validators_path(conn, :index, %{type: "JSON", filterMy: false}))
      assert {:ok, %{"items" => items, "next_page_path" => _}} = Poison.decode(conn.resp_body)
      assert Enum.count(items) == Enum.count(pools)
    end
  end

  describe "GET active_pools/2" do
    test "returns rendered table", %{conn: conn} do
      pools = Enum.map(1..4, fn _ -> insert(:staking_pool) end)

      conn = get(conn, active_pools_path(conn, :index, %{type: "JSON", filterMy: false}))
      assert {:ok, %{"items" => items, "next_page_path" => _}} = Poison.decode(conn.resp_body)
      assert Enum.count(items) == Enum.count(pools)
    end
  end

  describe "GET inactive_pools/2" do
    test "returns rendered table", %{conn: conn} do
      pools = Enum.map(1..4, fn _ -> insert(:staking_pool, is_active: false) end)

      conn = get(conn, inactive_pools_path(conn, :index, %{type: "JSON", filterMy: false}))
      assert {:ok, %{"items" => items, "next_page_path" => _}} = Poison.decode(conn.resp_body)
      assert Enum.count(items) == Enum.count(pools)
    end
  end
end
