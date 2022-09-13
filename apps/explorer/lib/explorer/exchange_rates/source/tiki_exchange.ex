defmodule Explorer.ExchangeRates.Source.TikiExchange do
  @moduledoc """
  Adapter for fetching exchange rates from https://api.tiki.vn.
  """

  alias Explorer.Chain
  alias Explorer.ExchangeRates.{Source, Token}

  import Source, only: [to_decimal: 1]

  require Logger

  @behaviour Source

  @impl Source
  def format_data(json_data) do
    last_updated = get_last_updated(json_data)
    current_price = get_current_price(json_data)
    id = "ASA"
    btc_value = 0
    circulating_supply_data = Enum.at(get_supply(), 0)
    total_supply_data = 0
    market_cap_data = get_market_cap(circulating_supply_data, current_price)
    total_volume_data = json_data["ticker"] && json_data["ticker"]["volume"]

    [
      %Token{
        available_supply: to_decimal(circulating_supply_data),
        total_supply: to_decimal(total_supply_data) || to_decimal(circulating_supply_data),
        btc_value: btc_value,
        id: id,
        last_updated: last_updated,
        market_cap_usd: to_decimal(market_cap_data),
        name: "Astra",
        symbol: Explorer.coin(),
        usd_value: current_price,
        volume_24h_usd: to_decimal(total_volume_data)
      }
    ]
  end

  @impl Source
  def headers do
    []
  end

  defp get_supply() do
    url = base_api_url() <> "/cosmos/bank/v1beta1/supply"
    case Source.http_request(url, headers()) do
      {:error, reason} ->
        Logger.error("failed to get supply: ", inspect(reason))
      {:ok, result} ->
        if is_map(result) do
          list_supply = result["supply"]
          for %{"amount" => amount, "denom" => denom} when denom == "aastra" <- list_supply do
            String.slice(amount, 0..-19)
          end
        else
          [0]
        end
    end
  end

  defp get_market_cap(nil, _price), do: Decimal.new(0)

  defp get_market_cap(supply, price) do
    supply
    |> to_decimal()
    |> Decimal.mult(price)
  end

  defp get_last_updated(json_data) do
    last_updated_json = Enum.at(json_data, 0)
    {:ok, last_updated_data} = DateTime.from_unix(String.to_integer(elem(last_updated_json, 1)))
    if last_updated_data do
      last_updated_data
    else
      nil
    end
  end

  defp get_current_price(json_data) do
    ticker = json_data["ticker"]
    if ticker do
      to_decimal(ticker["last"])
    else
      1
    end
  end

  @impl Source
  def source_url do
    "#{base_url()}"
  end

  @impl Source
  def source_url(input) do
    case Chain.Hash.Address.cast(input) do
      {:ok, _} ->
        address_hash_str = input
        "#{coin_gecko_url()}/coins/ethereum/contract/#{address_hash_str}"

      _ ->
        symbol = input

        id =
          case coin_id(symbol) do
            {:ok, id} ->
              id

            _ ->
              nil
          end

        if id, do: "#{coin_gecko_url()}/coins/#{id}", else: nil
    end
  end

  @spec base_api_url :: String.t()
  defp base_api_url() do
    System.get_env("API_NODE_URL")
  end

  defp base_url do
    config(:base_url) || "https://api.tiki.vn/sandseel/api/v2/public/markets/astra/summary"
  end

  defp coin_gecko_url do
    "https://api.coingecko.com/api/v3"
  end

  def coin_id do
    symbol = String.downcase(Explorer.coin())

    coin_id(symbol)
  end

  def coin_id(symbol) do
    id_mapping = bridged_token_symbol_to_id_mapping_to_get_price(symbol)

    if id_mapping do
      {:ok, id_mapping}
    else
      url = "#{coin_gecko_url()}/coins/list"

      symbol_downcase = String.downcase(symbol)

      case Source.http_request(url, headers()) do
        {:ok, data} = resp ->
          if is_list(data) do
            symbol_data =
              Enum.find(data, fn item ->
                item["symbol"] == symbol_downcase
              end)

            if symbol_data do
              {:ok, symbol_data["id"]}
            else
              {:error, :not_found}
            end
          else
            resp
          end

        resp ->
          resp
      end
    end
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  defp bridged_token_symbol_to_id_mapping_to_get_price(symbol) do
    case symbol do
      "UNI" -> "uniswap"
      "SURF" -> "surf-finance"
      _symbol -> nil
    end
  end
end