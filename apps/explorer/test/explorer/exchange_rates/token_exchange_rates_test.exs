defmodule Explorer.TokenExchangeRatesTest do
  use Explorer.DataCase

  import Mox

  alias Plug.Conn
  alias Explorer.Chain.Token
  alias Explorer.ExchangeRates.TokenExchangeRates

  @moduletag :capture_log

  setup :verify_on_exit!

  describe "handle_info(:fetch, state)" do
    setup do
      rates_configuration = Application.get_env(:explorer, Explorer.ExchangeRates.TokenExchangeRates)

      Application.put_env(:explorer, Explorer.ExchangeRates.TokenExchangeRates,
        interval: 0,
        platform: "ethereum",
        currency: "usd",
        enabled: true
      )

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.ExchangeRates.TokenExchangeRates, rates_configuration)
      end)
    end

    test "success fetch" do
      bypass = Bypass.open()

      Application.put_env(:explorer, Explorer.ExchangeRates.Source.CoinGecko,
        base_url: "http://localhost:#{bypass.port}"
      )

      [_token_with_no_exchange_rate | tokens] =
        for _ <- 0..4 do
          insert(:token, fiat_value: nil)
        end

      coins_list =
        tokens
        |> Enum.map(fn %{contract_address_hash: contract_address_hash} ->
          contract_address_hash_str = to_string(contract_address_hash)

          %{
            "id" => "#{contract_address_hash_str}_id",
            "symbol" => "#{contract_address_hash_str}_symbol",
            "name" => "#{contract_address_hash_str}_name",
            "platforms" => %{
              "some_other_chain" => "we do not want this to appear in the /simple/token_price/ request",
              "ethereum" => contract_address_hash_str
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
          Map.put(acc, contract_address_hash, %{
            "usd" => 1..100 |> Enum.random() |> Decimal.new() |> Decimal.mult(Decimal.from_float(0.7))
          })
        end)

      joined_addresses =
        tokens
        |> Enum.map_join(",", fn %{contract_address_hash: contract_address_hash} -> to_string(contract_address_hash) end)

      Bypass.expect_once(
        bypass,
        "GET",
        "/simple/token_price/ethereum",
        fn conn ->
          assert conn.query_string == "vs_currencies=usd&include_market_cap=true&contract_addresses=#{joined_addresses}"
          Conn.resp(conn, 200, Jason.encode!(token_exchange_rates))
        end
      )

      GenServer.start_link(TokenExchangeRates, [])

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{contract_address_hash: contract_address_hash, fiat_value: fiat_value} ->
        assert token_exchange_rates[contract_address_hash]["usd"] == fiat_value
      end)
    end

    test "empty body in /coins/list response" do
      bypass = Bypass.open()

      Application.put_env(:explorer, Explorer.ExchangeRates.Source.CoinGecko,
        base_url: "http://localhost:#{bypass.port}"
      )

      [_token_with_no_exchange_rate | _tokens] =
        for _ <- 0..4 do
          insert(:token, fiat_value: nil)
        end

      Bypass.expect_once(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 200, "[]")
      end)

      GenServer.start_link(TokenExchangeRates, [])

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{fiat_value: fiat_value} -> assert is_nil(fiat_value) end)
    end

    test "empty body in fetch response" do
      bypass = Bypass.open()

      Application.put_env(:explorer, Explorer.ExchangeRates.Source.CoinGecko,
        base_url: "http://localhost:#{bypass.port}"
      )

      [_token_with_no_exchange_rate | tokens] =
        for _ <- 0..4 do
          insert(:token, fiat_value: nil)
        end

      coins_list =
        tokens
        |> Enum.map(fn %{contract_address_hash: contract_address_hash} ->
          contract_address_hash_str = to_string(contract_address_hash)

          %{
            "id" => "#{contract_address_hash_str}_id",
            "symbol" => "#{contract_address_hash_str}_symbol",
            "name" => "#{contract_address_hash_str}_name",
            "platforms" => %{
              "some_other_chain" => "we do not want this to appear in the /simple/token_price/ request",
              "ethereum" => contract_address_hash_str
            }
          }
        end)

      Bypass.expect_once(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 200, Jason.encode!(coins_list))
      end)

      joined_addresses =
        tokens
        |> Enum.map_join(",", fn %{contract_address_hash: contract_address_hash} -> to_string(contract_address_hash) end)

      Bypass.expect_once(
        bypass,
        "GET",
        "/simple/token_price/ethereum",
        fn conn ->
          assert conn.query_string == "vs_currencies=usd&include_market_cap=true&contract_addresses=#{joined_addresses}"
          Conn.resp(conn, 200, "{}")
        end
      )

      GenServer.start_link(TokenExchangeRates, [])

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{fiat_value: fiat_value} -> assert is_nil(fiat_value) end)
    end

    test "error in /coins/list response" do
      bypass = Bypass.open()

      Application.put_env(:explorer, Explorer.ExchangeRates.Source.CoinGecko,
        base_url: "http://localhost:#{bypass.port}"
      )

      [_token_with_no_exchange_rate | _tokens] =
        for _ <- 0..4 do
          insert(:token, fiat_value: nil)
        end

      Bypass.expect_once(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 429, "Too many requests")
      end)

      GenServer.start_link(TokenExchangeRates, [])

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{fiat_value: fiat_value} -> assert is_nil(fiat_value) end)
    end

    test "error in fetch response" do
      bypass = Bypass.open()

      Application.put_env(:explorer, Explorer.ExchangeRates.Source.CoinGecko,
        base_url: "http://localhost:#{bypass.port}"
      )

      [_token_with_no_exchange_rate | tokens] =
        for _ <- 0..4 do
          insert(:token, fiat_value: nil)
        end

      coins_list =
        tokens
        |> Enum.map(fn %{contract_address_hash: contract_address_hash} ->
          contract_address_hash_str = to_string(contract_address_hash)

          %{
            "id" => "#{contract_address_hash_str}_id",
            "symbol" => "#{contract_address_hash_str}_symbol",
            "name" => "#{contract_address_hash_str}_name",
            "platforms" => %{
              "some_other_chain" => "we do not want this to appear in the /simple/token_price/ request",
              "ethereum" => contract_address_hash_str
            }
          }
        end)

      Bypass.expect_once(bypass, "GET", "/coins/list", fn conn ->
        assert conn.query_string == "include_platform=true"
        Conn.resp(conn, 200, Jason.encode!(coins_list))
      end)

      joined_addresses =
        tokens
        |> Enum.map_join(",", fn %{contract_address_hash: contract_address_hash} -> to_string(contract_address_hash) end)

      Bypass.expect_once(
        bypass,
        "GET",
        "/simple/token_price/ethereum",
        fn conn ->
          assert conn.query_string == "vs_currencies=usd&include_market_cap=true&contract_addresses=#{joined_addresses}"
          Conn.resp(conn, 429, "Too many requests")
        end
      )

      GenServer.start_link(TokenExchangeRates, [])

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{fiat_value: fiat_value} -> assert is_nil(fiat_value) end)
    end
  end
end
