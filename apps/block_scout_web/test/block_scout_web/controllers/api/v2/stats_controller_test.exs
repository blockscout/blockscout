defmodule BlockScoutWeb.API.V2.StatsControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Counters.{AddressesCount, AverageBlockTime}

  describe "/stats" do
    setup do
      start_supervised!(AddressesCount)
      start_supervised!(AverageBlockTime)

      Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

      on_exit(fn ->
        Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
      end)

      :ok
    end

    test "get all fields", %{conn: conn} do
      request = get(conn, "/api/v2/stats")
      assert response = json_response(request, 200)

      assert Map.has_key?(response, "total_blocks")
      assert Map.has_key?(response, "total_addresses")
      assert Map.has_key?(response, "total_transactions")
      assert Map.has_key?(response, "average_block_time")
      assert Map.has_key?(response, "coin_price")
      assert Map.has_key?(response, "total_gas_used")
      assert Map.has_key?(response, "transactions_today")
      assert Map.has_key?(response, "gas_used_today")
      assert Map.has_key?(response, "gas_prices")
      assert Map.has_key?(response, "static_gas_price")
      assert Map.has_key?(response, "market_cap")
      assert Map.has_key?(response, "network_utilization_percentage")
    end
  end

  describe "/stats/charts/market" do
    setup do
      configuration = Application.get_env(:explorer, Explorer.Market.MarketHistoryCache)
      Application.put_env(:explorer, Explorer.Market.MarketHistoryCache, cache_period: 0)

      :ok

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Market.MarketHistoryCache, configuration)
      end)
    end

    test "get empty data", %{conn: conn} do
      request = get(conn, "/api/v2/stats/charts/market")
      assert response = json_response(request, 200)

      assert response["chart_data"] == []
    end
  end

  describe "/stats/charts/transactions" do
    test "get empty data", %{conn: conn} do
      request = get(conn, "/api/v2/stats/charts/transactions")
      assert response = json_response(request, 200)

      assert response["chart_data"] == []
    end
  end

  describe "/stats/hot-smart-contracts" do
    import Explorer.Factory
    alias Explorer.Repo
    alias Explorer.Stats.HotSmartContracts

    setup do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)
      :ok
    end

    defp insert_hot_smart_contracts_daily(count, date \\ Date.utc_today(), scam \\ 0) do
      addresses = Enum.map(1..count, fn _ -> insert(:address) end)

      Enum.each(addresses, fn addr ->
        %HotSmartContracts{
          date: date,
          contract_address_hash: addr.hash,
          transactions_count: 1,
          total_gas_used: Decimal.new(21_000)
        }
        |> HotSmartContracts.changeset(%{})
        |> Repo.insert!()
      end)

      addresses
      |> Enum.take(-scam)
      |> Enum.each(fn addr -> insert(:scam_badge_to_address, address_hash: addr.hash) end)

      addresses
    end

    defp insert_transactions_in_last_seconds(count, seconds_ago, scam \\ 0) do
      now = DateTime.utc_now()
      from_ts = DateTime.add(now, -seconds_ago, :second)

      # Ensure strict boundary blocks exist
      some_block_in_beginning = insert(:block, timestamp: DateTime.add(from_ts, -1, :second))
      _from_block = insert(:block, timestamp: DateTime.add(from_ts, 1, :second))
      to_block = insert(:block, timestamp: DateTime.add(now, -1, :second))

      addresses = Enum.map(1..count, fn _ -> insert(:contract_address) end)

      Enum.each(addresses, fn addr ->
        insert(:transaction, to_address: addr)
        |> with_block(to_block, gas_used: 21_000)
      end)

      insert(:transaction, to_address: insert(:contract_address))
      |> with_block(some_block_in_beginning, gas_used: 21_000)

      addresses
      |> Enum.take(-scam)
      |> Enum.each(fn addr -> insert(:scam_badge_to_address, address_hash: addr.hash) end)

      addresses
    end

    test "empty stats works for short scale", %{conn: conn} do
      request = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "5m"})
      assert %{"items" => items, "next_page_params" => nil} = json_response(request, 200)
      assert length(items) == 0
    end

    test "empty stats works for long scale", %{conn: conn} do
      request = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "7d"})
      assert %{"items" => items, "next_page_params" => nil} = json_response(request, 200)
      assert length(items) == 0
    end

    # Daily scales pagination
    test "1d pagination", %{conn: conn} do
      insert_hot_smart_contracts_daily(55)

      request = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "1d"})
      assert %{"items" => items, "next_page_params" => next_page_params} = json_response(request, 200)

      assert length(items) == 50
      assert is_map(next_page_params)
      assert Map.has_key?(next_page_params, "contract_address_hash")
      assert Map.has_key?(next_page_params, "transactions_count")
      assert Map.has_key?(next_page_params, "total_gas_used")

      request = get(conn, "/api/v2/stats/hot-smart-contracts", Map.merge(next_page_params, %{scale: "1d"}))
      assert %{"items" => items, "next_page_params" => nil} = json_response(request, 200)
      assert length(items) == 5
    end

    test "7d pagination", %{conn: conn} do
      insert_hot_smart_contracts_daily(55)

      insert_hot_smart_contracts_daily(55, Date.add(Date.utc_today(), -8))

      request = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "7d"})
      assert %{"items" => items, "next_page_params" => next_page_params} = json_response(request, 200)

      assert length(items) == 50
      assert is_map(next_page_params)

      request = get(conn, "/api/v2/stats/hot-smart-contracts", Map.merge(next_page_params, %{scale: "7d"}))
      assert %{"items" => items, "next_page_params" => nil} = json_response(request, 200)
      assert length(items) == 5
    end

    test "30d pagination", %{conn: conn} do
      insert_hot_smart_contracts_daily(55)

      insert_hot_smart_contracts_daily(55, Date.add(Date.utc_today(), -31))

      request = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "30d"})
      assert %{"items" => items, "next_page_params" => next_page_params} = json_response(request, 200)

      assert length(items) == 50
      assert is_map(next_page_params)

      request = get(conn, "/api/v2/stats/hot-smart-contracts", Map.merge(next_page_params, %{scale: "30d"}))
      assert %{"items" => items, "next_page_params" => nil} = json_response(request, 200)
      assert length(items) == 5
    end

    # Daily scales scam toggle
    test "1d scam toggle respects cookie and hide config", %{conn: conn} do
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)

      [normal | [scam | _]] = insert_hot_smart_contracts_daily(2, Date.utc_today(), 1)

      # Without cookie -> hide scam
      request1 = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "1d"})
      resp1 = json_response(request1, 200)
      hashes1 = Enum.map(resp1["items"], fn %{"contract_address" => %{"hash" => h}} -> h end)
      assert Address.checksum(normal.hash) in hashes1
      refute Address.checksum(scam.hash) in hashes1

      # With cookie -> show scam
      request2 =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/stats/hot-smart-contracts", %{scale: "1d"})

      resp2 = json_response(request2, 200)
      hashes2 = Enum.map(resp2["items"], fn %{"contract_address" => %{"hash" => h}} -> h end)
      assert Address.checksum(normal.hash) in hashes2
      assert Address.checksum(scam.hash) in hashes2
    end

    # Seconds scales pagination (seed once covers all three)
    test "5m pagination", %{conn: conn} do
      insert_transactions_in_last_seconds(55, 300)

      request = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "5m"})
      assert %{"items" => items, "next_page_params" => next_page_params} = json_response(request, 200)
      assert length(items) == 50
      assert is_map(next_page_params)

      request = get(conn, "/api/v2/stats/hot-smart-contracts", Map.merge(next_page_params, %{scale: "5m"}))
      assert %{"items" => items, "next_page_params" => nil} = json_response(request, 200)
      assert length(items) == 5
    end

    test "1h pagination", %{conn: conn} do
      insert_transactions_in_last_seconds(55, 3600)

      request = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "1h"})
      assert %{"items" => items, "next_page_params" => next_page_params} = json_response(request, 200)
      assert length(items) == 50
      assert is_map(next_page_params)

      request = get(conn, "/api/v2/stats/hot-smart-contracts", Map.merge(next_page_params, %{scale: "1h"}))
      assert %{"items" => items, "next_page_params" => nil} = json_response(request, 200)
      assert length(items) == 5
    end

    test "3h pagination", %{conn: conn} do
      addresses = insert_transactions_in_last_seconds(55, 10800)

      addresses =
        Enum.map(addresses, fn addr -> to_string(addr.hash) end)

      request = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "3h"})
      assert %{"items" => items, "next_page_params" => next_page_params} = json_response(request, 200)
      assert length(items) == 50
      assert is_map(next_page_params)

      request = get(conn, "/api/v2/stats/hot-smart-contracts", Map.merge(next_page_params, %{scale: "3h"}))
      assert %{"items" => items, "next_page_params" => nil} = json_response(request, 200)
      assert length(items) == 5
    end

    # Seconds scales scam toggle
    test "5m scam toggle respects cookie and hide config", %{conn: conn} do
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)

      [normal | [scam | _]] = insert_transactions_in_last_seconds(2, 300, 1)

      request1 = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "5m"})
      resp1 = json_response(request1, 200)
      hashes1 = Enum.map(resp1["items"], fn %{"contract_address" => %{"hash" => h}} -> h end)
      assert Address.checksum(normal.hash) in hashes1
      refute Address.checksum(scam.hash) in hashes1

      request2 =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/stats/hot-smart-contracts", %{scale: "5m"})

      resp2 = json_response(request2, 200)
      hashes2 = Enum.map(resp2["items"], fn %{"contract_address" => %{"hash" => h}} -> h end)
      assert Address.checksum(normal.hash) in hashes2
      assert Address.checksum(scam.hash) in hashes2
    end

    test "1h scam toggle respects cookie and hide config", %{conn: conn} do
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)

      [normal | [scam | _]] = insert_transactions_in_last_seconds(2, 300, 1)

      request1 = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "1h"})
      resp1 = json_response(request1, 200)
      hashes1 = Enum.map(resp1["items"], fn %{"contract_address" => %{"hash" => h}} -> h end)
      assert Address.checksum(normal.hash) in hashes1
      refute Address.checksum(scam.hash) in hashes1

      request2 =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/stats/hot-smart-contracts", %{scale: "1h"})

      resp2 = json_response(request2, 200)
      hashes2 = Enum.map(resp2["items"], fn %{"contract_address" => %{"hash" => h}} -> h end)
      assert Address.checksum(normal.hash) in hashes2
      assert Address.checksum(scam.hash) in hashes2
    end

    test "3h scam toggle respects cookie and hide config", %{conn: conn} do
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)

      [normal | [scam | _]] = insert_transactions_in_last_seconds(2, 300, 1)

      request1 = get(conn, "/api/v2/stats/hot-smart-contracts", %{scale: "3h"})
      resp1 = json_response(request1, 200)
      hashes1 = Enum.map(resp1["items"], fn %{"contract_address" => %{"hash" => h}} -> h end)
      assert Address.checksum(normal.hash) in hashes1
      refute Address.checksum(scam.hash) in hashes1

      request2 =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/stats/hot-smart-contracts", %{scale: "3h"})

      resp2 = json_response(request2, 200)
      hashes2 = Enum.map(resp2["items"], fn %{"contract_address" => %{"hash" => h}} -> h end)
      assert Address.checksum(normal.hash) in hashes2
      assert Address.checksum(scam.hash) in hashes2
    end
  end
end
