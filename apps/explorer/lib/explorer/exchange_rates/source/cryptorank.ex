defmodule Explorer.ExchangeRates.Source.Cryptorank do
  @moduledoc """
  Adapter for fetching exchange rates from https://cryptorank.io
  """

  alias Explorer.ExchangeRates.{Source, Token}
  alias Explorer.ExchangeRates.Source.CoinGecko
  alias Explorer.Market.History.Source.Price, as: SourcePrice

  import Source, only: [to_decimal: 1, maybe_get_date: 1, handle_image_url: 1]

  @spec format_data(term()) :: [Token.t()] | map()
  def format_data(%{"data" => %{} = coin}) do
    last_updated = maybe_get_date(coin["lastUpdated"])

    btc_value =
      if Application.get_env(:explorer, Explorer.ExchangeRates)[:fetch_btc_value],
        do: coin["values"]["BTC"] && coin["values"]["BTC"]["price"]

    image_url = coin["images"] && (coin["images"]["200x200"] || coin["images"]["60x60"])
    usd = coin["values"]["USD"]

    [
      %Token{
        available_supply: to_decimal(coin["circulatingSupply"]),
        total_supply: to_decimal(coin["totalSupply"]) || to_decimal(coin["circulatingSupply"]),
        btc_value: btc_value,
        id: coin["id"],
        last_updated: last_updated,
        market_cap_usd: to_decimal(usd["marketCap"]),
        tvl_usd: nil,
        name: coin["name"],
        symbol: String.upcase(coin["symbol"]),
        usd_value: to_decimal(usd["price"]),
        volume_24h_usd: to_decimal(usd["volume24h"]),
        image_url: handle_image_url(image_url)
      }
    ]
  end

  def format_data(%{"data" => currencies, "meta" => %{"count" => count}}) when is_list(currencies) do
    platform_id = platform_id()
    currencies |> Enum.reduce(%{}, &reduce_currency(platform_id, &1, &2)) |> Map.put(:count, count)
  end

  @spec format_data(term(), boolean()) :: [SourcePrice.record()] | nil
  defp format_data(nil, _), do: nil

  defp format_data(%{"data" => %{"dates" => dates, "prices" => prices}}, secondary_coin?) do
    dates
    |> Enum.zip(prices)
    |> Enum.reverse()
    |> Enum.map_reduce(nil, fn {date, price}, next_day_opening ->
      if next_day_opening do
        {%{
           closing_price: Decimal.new(to_string(next_day_opening)),
           date: CoinGecko.date(date),
           opening_price: Decimal.new(to_string(price)),
           secondary_coin: secondary_coin?
         }, price}
      else
        {%{
           closing_price: Decimal.new(to_string(price)),
           date: CoinGecko.date(date),
           opening_price: Decimal.new(to_string(price)),
           secondary_coin: secondary_coin?
         }, price}
      end
    end)
    |> elem(0)
    |> Enum.reject(&is_nil/1)
    |> Enum.reverse()
  end

  def source_url(:market) do
    base_url() |> URI.append_path("/global") |> URI.to_string()
  end

  def source_url do
    if coin_id() do
      base_url() |> URI.append_path("/currencies/#{coin_id()}") |> URI.to_string()
    end
  end

  def source_url(:currencies, limit, offset) do
    base_url()
    |> URI.append_path("/dedicated/blockscout/currencies/contracts/#{platform_id()}")
    |> URI.append_query("limit=#{limit}")
    |> URI.append_query("skip=#{offset}")
    |> URI.to_string()
  end

  @spec history_url(non_neg_integer(), boolean()) :: String.t()
  def history_url(previous_days, secondary_coin? \\ false) do
    from = Date.utc_today() |> Date.add(-previous_days) |> Date.to_iso8601()
    to = Date.utc_today() |> Date.to_iso8601()
    coin_id = if secondary_coin?, do: secondary_coin_id(), else: coin_id()

    base_url()
    |> URI.append_path("/currencies/#{coin_id}/sparkline")
    |> URI.append_query("interval=1d")
    |> URI.append_query("from=#{from}")
    |> URI.append_query("to=#{to}")
    |> URI.to_string()
  end

  def headers do
    []
  end

  defp base_url do
    config()[:base_url] |> URI.parse() |> URI.append_query("api_key=#{api_key()}")
  end

  defp api_key do
    config()[:api_key]
  end

  defp platform_id do
    config()[:platform]
  end

  defp coin_id do
    config()[:coin_id]
  end

  defp secondary_coin_id do
    config()[:secondary_coin_id]
  end

  defp config do
    Application.get_env(:explorer, __MODULE__)
  end

  @spec fetch_price_history(non_neg_integer(), boolean()) :: {:ok, [SourcePrice.record()]} | :error
  def fetch_price_history(previous_days, secondary_coin? \\ false) do
    url = history_url(previous_days, secondary_coin?)

    case Source.http_request(url, headers()) do
      {:ok, data} ->
        result =
          data |> format_data(secondary_coin?)

        {:ok, result}

      _ ->
        :error
    end
  end

  defp reduce_currency(platform_id, %{"contracts" => [_ | _] = tokens} = currency, acc) do
    Enum.reduce(tokens, acc, fn
      %{
        "address" => token_address_hash_string,
        "chainId" => ^platform_id
      },
      acc ->
        market_cap =
          currency["priceUSD"] && currency["circulatingSupply"] &&
            Decimal.mult(
              Decimal.new(currency["priceUSD"]),
              Decimal.new(currency["circulatingSupply"])
            )

        Map.put(acc, token_address_hash_string, %{
          fiat_value: currency["priceUSD"],
          circulating_market_cap: market_cap,
          volume_24h: currency["volume24hUSD"]
        })

      _, acc ->
        acc
    end)
  end

  defp reduce_currency(_, _, acc) do
    acc
  end
end
