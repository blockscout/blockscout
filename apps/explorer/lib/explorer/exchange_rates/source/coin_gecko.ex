defmodule Explorer.ExchangeRates.Source.CoinGecko do
  @moduledoc """
  Adapter for fetching exchange rates from https://coingecko.com
  """

  alias Explorer.ExchangeRates.{Source, Token}
  alias HTTPoison.{Error, Response}

  import Source, only: [decode_json: 1, to_decimal: 1, headers: 0]

  @behaviour Source

  @impl Source
  def format_data(%{"market_data" => _} = json_data) do
    {:ok, price} = get_btc_price()
    btc_price = to_decimal(price)

    market_data = json_data["market_data"]
    {:ok, last_updated, 0} = DateTime.from_iso8601(market_data["last_updated"])

    current_price = to_decimal(market_data["current_price"]["usd"])

    id = json_data["id"]
    btc_value = if id != "btc", do: Decimal.div(current_price, btc_price), else: 1

    [
      %Token{
        available_supply: to_decimal(market_data["circulating_supply"]),
        total_supply: to_decimal(market_data["total_supply"]) || to_decimal(market_data["circulating_supply"]),
        btc_value: btc_value,
        id: json_data["id"],
        last_updated: last_updated,
        market_cap_usd: to_decimal(market_data["market_cap"]["usd"]),
        name: json_data["name"],
        symbol: String.upcase(json_data["symbol"]),
        usd_value: current_price,
        volume_24h_usd: to_decimal(market_data["total_volume"]["usd"])
      }
    ]
  end

  @impl Source
  def format_data(_), do: []

  @impl Source
  def source_url do
    explicit_coin_id = Application.get_env(:explorer, :coingecko_coin_id)

    {:ok, id} =
      if explicit_coin_id do
        {:ok, explicit_coin_id}
      else
        case coin_id() do
          {:ok, id} ->
            {:ok, id}

          _ ->
            {:ok, nil}
        end
      end

    if id, do: "#{base_url()}/coins/#{id}", else: nil
  end

  @impl Source
  def source_url(symbol) do
    id =
      case coin_id(symbol) do
        {:ok, id} ->
          id

        _ ->
          nil
      end

    if id, do: "#{base_url()}/coins/#{id}", else: nil
  end

  defp base_url do
    config(:base_url) || "https://api.coingecko.com/api/v3"
  end

  def coin_id do
    symbol = String.downcase(Explorer.coin())

    coin_id(symbol)
  end

  def coin_id(symbol) do
    url = "#{base_url()}/coins/list"

    symbol_downcase = String.downcase(symbol)

    case HTTPoison.get(url, headers()) do
      {:ok, %Response{body: body, status_code: 200}} ->
        data = decode_json(body)

        symbol_data =
          Enum.find(data, fn item ->
            item["symbol"] == symbol_downcase
          end)

        if symbol_data do
          {:ok, symbol_data["id"]}
        else
          {:error, :not_found}
        end

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..499 ->
        {:error, decode_json(body)["error"]}

      {:error, %Error{reason: reason}} ->
        {:error, reason}

      {:error, :nxdomain} ->
        {:error, "CoinGecko is not responsive"}
    end
  end

  defp get_btc_price(currency \\ "usd") do
    url = "#{base_url()}/exchange_rates"

    case HTTPoison.get(url, headers()) do
      {:ok, %Response{body: body, status_code: 200}} ->
        data = decode_json(body)
        current_price = data["rates"][currency]["value"]

        {:ok, current_price}

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..499 ->
        {:error, decode_json(body)["error"]}

      {:error, %Error{reason: reason}} ->
        {:error, reason}

      {:error, :nxdomain} ->
        {:error, "CoinGecko is not responsive"}
    end
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end
end
