defmodule Explorer.TokenExchangeRatesTest do
  # use ExUnit.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Plug.Conn
  alias Explorer.Chain.Token
  alias Explorer.ExchangeRates
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

      tokens =
        for _ <- 0..4 do
          insert(:token)
        end

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

      Bypass.expect_once(bypass, fn conn ->
        assert conn.method == "GET"

        assert "#{conn.request_path}?#{conn.query_string}" ==
                 "/simple/token_price/ethereum?vs_currencies=usd&contract_addresses=#{joined_addresses}"

        Conn.resp(conn, 200, Jason.encode!(token_exchange_rates))
      end)

      GenServer.start_link(TokenExchangeRates, [])

      set_mox_global()

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{contract_address_hash: contract_address_hash, fiat_value: fiat_value} ->
        assert token_exchange_rates[contract_address_hash]["usd"] == fiat_value
      end)
    end

    test "empty body in fetch response" do
      bypass = Bypass.open()

      Application.put_env(:explorer, Explorer.ExchangeRates.Source.CoinGecko,
        base_url: "http://localhost:#{bypass.port}"
      )

      tokens =
        for _ <- 0..4 do
          insert(:token)
        end

      joined_addresses =
        tokens
        |> Enum.map_join(",", fn %{contract_address_hash: contract_address_hash} -> to_string(contract_address_hash) end)

      Bypass.expect_once(bypass, fn conn ->
        assert conn.method == "GET"

        assert "#{conn.request_path}?#{conn.query_string}" ==
                 "/simple/token_price/ethereum?vs_currencies=usd&contract_addresses=#{joined_addresses}"

        Conn.resp(conn, 200, "{}")
      end)

      GenServer.start_link(TokenExchangeRates, [])

      set_mox_global()

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{fiat_value: fiat_value} -> assert is_nil(fiat_value) end)
    end

    test "error in retch response" do
      bypass = Bypass.open()

      Application.put_env(:explorer, Explorer.ExchangeRates.Source.CoinGecko,
        base_url: "http://localhost:#{bypass.port}"
      )

      tokens =
        for _ <- 0..4 do
          insert(:token)
        end

      joined_addresses =
        tokens
        |> Enum.map_join(",", fn %{contract_address_hash: contract_address_hash} -> to_string(contract_address_hash) end)

      Bypass.expect_once(bypass, fn conn ->
        assert conn.method == "GET"

        assert "#{conn.request_path}?#{conn.query_string}" ==
                 "/simple/token_price/ethereum?vs_currencies=usd&contract_addresses=#{joined_addresses}"

        Conn.resp(conn, 429, "Too Many Requests")
      end)

      GenServer.start_link(TokenExchangeRates, [])

      set_mox_global()

      :timer.sleep(100)

      Repo.all(Token)
      |> Enum.each(fn %{fiat_value: fiat_value} -> assert is_nil(fiat_value) end)
    end
  end
end
