defmodule Explorer.ExchangeRates.Source.BW do
  @moduledoc """
  Adapter for fetching exchange rates from https://bw.com
  """

  alias Explorer.ExchangeRates.{Source, Token}
  alias Explorer.Chain.Wei
  alias HTTPoison.{Error, Response}

  import Source, only: [decode_json: 1, to_decimal: 1, headers: 0]

  @behaviour Source

  @impl Source
  def format_data(json_data) do
    {:ok, prices} = get_assist_price()
    
    coin = String.downcase(Explorer.coin())
    symbol_data =
          Enum.find(json_data["datas"], fn item ->
            item["name"] == coin
          end)

    market_data = prices["datas"]
    {:ok, last_updated} = DateTime.from_unix(symbol_data["modifyTime"], :millisecond)

    btc_price = to_decimal(market_data["usd"]["btc"])
    current_price = to_decimal(market_data["usd"][coin])

    id = symbol_data["currencyId"]    
    btc_value = if id != "2", do: Decimal.div(current_price, btc_price), else: 1    
    
    wei_supply = Explorer.Chain.fetch_sum_coin_total_supply_minus_burnt()
    available_supply = %Wei{value: wei_supply} |> Wei.to(:ether) |> Decimal.max(2_000_000_000)
    market_cap = Decimal.mult(available_supply, current_price)

    volume_24h = case get_ticker(coin) do
        {:ok, ticker} -> ticker["datas"] |> Enum.at(9)
        _ -> nil
    end

    [
      %Token{
        available_supply: available_supply,
        total_supply: nil,
        btc_value: btc_value,
        id: json_data["id"],
        last_updated: last_updated,
        market_cap_usd: market_cap,
        name: symbol_data["name"],
        symbol: String.upcase(symbol_data["name"]),
        usd_value: current_price,
        volume_24h_usd: to_decimal(volume_24h),
      }
    ]
  end

  @impl Source
  def source_url do
    "#{base_url()}/exchange/config/controller/website/currencycontroller/getCurrencyList"
  end

  defp base_url do
    config(:base_url) || "https://www.bw.com"
  end

  defp get_ticker(coin) do
    pair = coin <> "_usdt"
    url = "#{base_url()}/api/data/v1/ticker?marketName=#{pair}"

    case HTTPoison.get(url, headers()) do
      {:ok, %Response{body: body, status_code: 200}} ->
        {:ok, decode_json(body)}

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..499 ->
        {:error, decode_json(body)["error"]}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end 
  end

  defp get_assist_price do
    url = "#{base_url()}/exchange/config/controller/website/pricecontroller/getassistprice"

    case HTTPoison.get(url, headers()) do
      {:ok, %Response{body: body, status_code: 200}} ->
        {:ok, decode_json(body)}

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..499 ->
        {:error, decode_json(body)["error"]}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end
end
