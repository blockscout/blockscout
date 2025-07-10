defmodule Explorer.Market.Fetcher.TokenTest do
  use Explorer.DataCase

  import Mox

  alias Plug.Conn
  alias Explorer.Chain.Token
  alias Explorer.Market.Fetcher.Token, as: TokenFetcher

  @moduletag :capture_log

  setup :verify_on_exit!

  describe "handle_info(:fetch, state)" do
    setup do
      bypass = Bypass.open()

      source_configuration = Application.get_env(:explorer, Explorer.Market.Source)
      fetcher_configuration = Application.get_env(:explorer, Explorer.Market.Fetcher.Token)
      coin_gecko_configuration = Application.get_env(:explorer, Explorer.Market.Source.CoinGecko)

      Application.put_env(:explorer, Explorer.Market.Source, tokens_source: Explorer.Market.Source.CoinGecko)

      Application.put_env(:explorer, Explorer.Market.Fetcher.Token,
        enabled: true,
        interval: 0,
        refetch_interval: 10000,
        max_batch_size: 10
      )

      Application.put_env(:explorer, Explorer.Market.Source.CoinGecko,
        platform: "ethereum",
        currency: "usd",
        base_url: "http://localhost:#{bypass.port}"
      )

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Market.Source, source_configuration)
        Application.put_env(:explorer, Explorer.Market.Fetcher.Token, fetcher_configuration)
        Application.put_env(:explorer, Explorer.Market.Source.CoinGecko, coin_gecko_configuration)
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      end)

      [_token_with_no_exchange_rate | tokens] =
        for _ <- 0..4 do
          insert(:token, fiat_value: nil)
        end

      {:ok, %{bypass: bypass, tokens: tokens}}
    end

    test "success fetch", %{bypass: bypass, tokens: tokens} do
      coins_list =
        tokens
        |> Enum.map(fn %{contract_address_hash: contract_address_hash} ->
          %{
            "id" => "#{contract_address_hash}_id",
            "symbol" => "#{contract_address_hash}_symbol",
            "name" => "#{contract_address_hash}_name",
            "platforms" => %{
              "some_other_chain" => "we do not want this to appear in the /simple/token_price/ request",
              "ethereum" => "#{contract_address_hash}"
            }
          }
        end)

      Bypass.expect_once(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 200, Jason.encode!(coins_list))
      end)

      token_exchange_rates =
        tokens
        |> Enum.reduce(%{}, fn %{contract_address_hash: contract_address_hash}, acc ->
          Map.put(acc, "#{contract_address_hash}_id", %{
            "usd" => 1..100 |> Enum.random() |> Decimal.new() |> Decimal.mult(Decimal.from_float(0.7))
          })
        end)

      joined_ids =
        tokens
        |> Enum.reverse()
        |> Enum.map_join(",", fn %{contract_address_hash: contract_address_hash} -> "#{contract_address_hash}_id" end)

      Bypass.expect_once(
        bypass,
        "GET",
        "/simple/price",
        fn conn ->
          assert conn.query_string ==
                   "vs_currencies=usd&include_market_cap=true&include_24hr_vol=true&ids=#{joined_ids}"

          Conn.resp(conn, 200, Jason.encode!(token_exchange_rates))
        end
      )

      GenServer.start_link(TokenFetcher, [])

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{contract_address_hash: contract_address_hash, fiat_value: fiat_value} ->
        assert token_exchange_rates[contract_address_hash]["usd"] == fiat_value
      end)
    end

    test "empty body in /coins/list response", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 200, "[]")
      end)

      GenServer.start_link(TokenFetcher, [])

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{fiat_value: fiat_value} -> assert is_nil(fiat_value) end)
    end

    test "empty body in fetch response", %{bypass: bypass, tokens: tokens} do
      coins_list =
        tokens
        |> Enum.map(fn %{contract_address_hash: contract_address_hash} ->
          %{
            "id" => "#{contract_address_hash}_id",
            "symbol" => "#{contract_address_hash}_symbol",
            "name" => "#{contract_address_hash}_name",
            "platforms" => %{
              "some_other_chain" => "we do not want this to appear in the /simple/token_price/ request",
              "ethereum" => "#{contract_address_hash}"
            }
          }
        end)

      Bypass.expect_once(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 200, Jason.encode!(coins_list))
      end)

      joined_ids =
        tokens
        |> Enum.reverse()
        |> Enum.map_join(",", fn %{contract_address_hash: contract_address_hash} -> "#{contract_address_hash}_id" end)

      Bypass.expect_once(
        bypass,
        "GET",
        "/simple/price",
        fn conn ->
          assert conn.query_string ==
                   "vs_currencies=usd&include_market_cap=true&include_24hr_vol=true&ids=#{joined_ids}"

          Conn.resp(conn, 200, "{}")
        end
      )

      GenServer.start_link(TokenFetcher, [])

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{fiat_value: fiat_value} -> assert is_nil(fiat_value) end)
    end

    test "error in /coins/list response", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 429, "Too many requests")
      end)

      GenServer.start_link(TokenFetcher, [])

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{fiat_value: fiat_value} -> assert is_nil(fiat_value) end)
    end

    test "error in fetch response", %{bypass: bypass, tokens: tokens} do
      coins_list =
        tokens
        |> Enum.map(fn %{contract_address_hash: contract_address_hash} ->
          %{
            "id" => "#{contract_address_hash}_id",
            "symbol" => "#{contract_address_hash}_symbol",
            "name" => "#{contract_address_hash}_name",
            "platforms" => %{
              "some_other_chain" => "we do not want this to appear in the /simple/token_price/ request",
              "ethereum" => "#{contract_address_hash}"
            }
          }
        end)

      Bypass.expect(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 200, Jason.encode!(coins_list))
      end)

      joined_ids =
        tokens
        |> Enum.reverse()
        |> Enum.map_join(",", fn %{contract_address_hash: contract_address_hash} -> "#{contract_address_hash}_id" end)

      Bypass.expect(
        bypass,
        "GET",
        "/simple/price",
        fn conn ->
          assert conn.query_string ==
                   "vs_currencies=usd&include_market_cap=true&include_24hr_vol=true&ids=#{joined_ids}"

          Conn.resp(conn, 429, "Too many requests")
        end
      )

      GenServer.start_link(TokenFetcher, [])

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{fiat_value: fiat_value} -> assert is_nil(fiat_value) end)
    end
  end
end
