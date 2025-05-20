defmodule Explorer.Market.Source.CoinMarketCap do
  @moduledoc """
  Adapter for fetching exchange rates from https://coinmarketcap.com/api/
  """

  alias Explorer.Market
  alias Explorer.Market.{Source, Token}

  @behaviour Source

  @impl Source
  def native_coin_fetching_enabled?, do: not is_nil(config(:coin_id))

  @impl Source
  def fetch_native_coin, do: do_fetch_coin(config(:coin_id), "Coin ID not specified")

  @impl Source
  def secondary_coin_fetching_enabled?, do: not is_nil(config(:secondary_coin_id))

  @impl Source
  def fetch_secondary_coin, do: do_fetch_coin(config(:secondary_coin_id), "Secondary coin ID not specified")

  @impl Source
  def tokens_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_tokens(_state, _batch_size), do: :ignore

  @impl Source
  def native_coin_price_history_fetching_enabled?, do: not is_nil(config(:coin_id))

  @impl Source
  def fetch_native_coin_price_history(previous_days), do: do_fetch_coin_price_history(previous_days, false)

  @impl Source
  def secondary_coin_price_history_fetching_enabled?, do: not is_nil(config(:secondary_coin_id))

  @impl Source
  def fetch_secondary_coin_price_history(previous_days), do: do_fetch_coin_price_history(previous_days, true)

  @impl Source
  def market_cap_history_fetching_enabled?, do: not is_nil(config(:coin_id))

  @impl Source
  def fetch_market_cap_history(previous_days) do
    currency_id = config(:currency_id)

    with coin_id when not is_nil(coin_id) <- config(:coin_id),
         {:ok, %{"data" => market_data}} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/cryptocurrency/quotes/historical")
             |> URI.append_query("id=#{coin_id}")
             |> URI.append_query("count=#{previous_days}")
             |> URI.append_query("interval=daily")
             |> URI.append_query("convert_id=#{currency_id}")
             |> URI.append_query("aux=market_cap")
             |> URI.to_string(),
             headers()
           ) do
      quotes = market_data["quotes"]

      result =
        for %{"timestamp" => date, "quote" => %{^currency_id => %{"market_cap" => market_cap}}} <- quotes do
          date = Source.maybe_get_date(date)

          %{
            date: date && DateTime.to_date(date),
            market_cap: Source.to_decimal(market_cap)
          }
        end

      {:ok, result}
    else
      nil -> {:error, "Coin ID not specified"}
      {:ok, nil} -> {:ok, []}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("CoinMarketCap", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  @impl Source
  def tvl_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_tvl_history(_previous_days), do: :ignore

  defp do_fetch_coin(coin_id, coin_id_not_specified_error) do
    convert_id =
      if Application.get_env(:explorer, Market)[:fetch_btc_value],
        do: "1,#{config(:currency_id)}",
        else: config(:currency_id)

    with coin_id when not is_nil(coin_id) <- coin_id,
         {:ok, %{"data" => market_data}} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/cryptocurrency/quotes/latest")
             |> URI.append_query("id=#{coin_id}")
             |> URI.append_query("convert_id=#{convert_id}")
             |> URI.append_query("aux=circulating_supply,total_supply")
             |> URI.to_string(),
             headers()
           ) do
      token_properties = market_data |> Map.values() |> List.first() || %{}
      currency_id = token_properties["quote"][config(:currency_id)]

      {:ok,
       %Token{
         available_supply: Source.to_decimal(token_properties["circulating_supply"]),
         total_supply:
           Source.to_decimal(token_properties["total_supply"]) ||
             Source.to_decimal(token_properties["circulating_supply"]),
         btc_value: Source.to_decimal(token_properties["quote"]["1"]["price"]),
         last_updated: Source.maybe_get_date(currency_id["last_updated"]),
         market_cap: Source.to_decimal(currency_id["market_cap"]),
         tvl: Source.to_decimal(currency_id["tvl"]),
         name: token_properties["name"],
         symbol: String.upcase(token_properties["symbol"]),
         fiat_value: Source.to_decimal(currency_id["price"]),
         volume_24h: Source.to_decimal(currency_id["volume_24h"]),
         image_url: nil
       }}
    else
      nil ->
        {:error, coin_id_not_specified_error}

      {:ok, unexpected_response} ->
        {:error, Source.unexpected_response_error("CoinMarketCap", unexpected_response)}

      {:error, _reason} = error ->
        error
    end
  end

  defp do_fetch_coin_price_history(previous_days, secondary_coin?) do
    currency_id = config(:currency_id)

    with coin_id when not is_nil(coin_id) <-
           if(secondary_coin?, do: config(:secondary_coin_id), else: config(:coin_id)),
         {:ok, %{"data" => %{"quotes" => quotes}}} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/cryptocurrency/quotes/historical")
             |> URI.append_query("id=#{coin_id}")
             |> URI.append_query("count=#{previous_days}")
             |> URI.append_query("interval=daily")
             |> URI.append_query("convert_id=#{currency_id}")
             |> URI.append_query("aux=price")
             |> URI.to_string(),
             headers()
           ) do
      closing_quotes =
        case quotes do
          [_ | closing_quotes] -> closing_quotes
          _ -> []
        end

      result =
        for {%{"timestamp" => date, "quote" => %{^currency_id => %{"price" => opening_price}}}, closing_quote} <-
              Stream.zip(quotes, Stream.concat(closing_quotes, [nil])) do
          date = Source.maybe_get_date(date)

          case closing_quote do
            %{"quote" => %{^currency_id => %{"price" => closing_price}}} ->
              %{
                closing_price: Source.to_decimal(closing_price),
                date: date && DateTime.to_date(date),
                opening_price: Source.to_decimal(opening_price),
                secondary_coin: secondary_coin?
              }

            _ ->
              %{
                closing_price: Source.to_decimal(opening_price),
                date: date && DateTime.to_date(date),
                opening_price: Source.to_decimal(opening_price),
                secondary_coin: secondary_coin?
              }
          end
        end

      {:ok, result}
    else
      nil -> {:error, "#{Source.secondary_coin_string(secondary_coin?)} ID not specified"}
      {:ok, nil} -> {:ok, []}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("CoinMarketCap", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  defp base_url do
    URI.parse(config(:base_url))
  end

  defp headers do
    if config(:api_key), do: [{"X-CMC_PRO_API_KEY", "#{config(:api_key)}"}], else: []
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__)[key]
  end
end
