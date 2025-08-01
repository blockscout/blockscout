defmodule Explorer.Market.Source.CryptoRank do
  @moduledoc """
  Adapter for fetching market history from https://cryptorank.io/.
  """

  alias Explorer.Chain.Hash
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
  def tokens_fetching_enabled?, do: not is_nil(config(:platform))

  @impl Source
  def fetch_tokens(nil, batch_size), do: fetch_tokens(0, batch_size)

  @impl Source
  def fetch_tokens(skip, batch_size) do
    with platform_id when not is_nil(platform_id) <- config(:platform),
         {:ok, %{"data" => tokens}} when is_list(tokens) <-
           Source.http_request(
             base_url()
             |> URI.append_path("/dedicated/blockscout/currencies/contracts/#{platform_id}")
             |> URI.append_query("limit=#{batch_size}")
             |> URI.append_query("skip=#{skip}")
             |> URI.to_string(),
             headers()
           ) do
      {tokens_to_import, initial_tokens_len} =
        tokens |> Enum.reduce({[], 0}, &reduce_token(platform_id, &1, &2))

      fetch_finished? = initial_tokens_len < batch_size
      new_state = if fetch_finished?, do: nil, else: skip + batch_size
      {:ok, new_state, fetch_finished?, tokens_to_import}
    else
      nil -> {:error, "Platform ID not specified"}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("CryptoRank", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  defp reduce_token(platform_id, %{"contracts" => [_ | _] = tokens} = token, {tokens_to_import, count}) do
    tokens
    |> Enum.find_value(fn
      %{"chainId" => ^platform_id, "address" => token_contract_address_hash_string} ->
        case Hash.Address.cast(token_contract_address_hash_string) do
          {:ok, token_contract_address_hash} ->
            fiat_value = Source.to_decimal(token["priceUSD"])
            circulating_supply = Source.to_decimal(token["circulatingSupply"])

            %{
              symbol: token["symbol"],
              name: token["name"],
              fiat_value: fiat_value,
              volume_24h: Source.to_decimal(token["volume24hUSD"]),
              circulating_market_cap: circulating_supply && fiat_value && Decimal.mult(fiat_value, circulating_supply),
              contract_address_hash: token_contract_address_hash,
              type: "ERC-20"
            }

          _ ->
            false
        end

      _ ->
        false
    end)
    |> case do
      nil -> {tokens_to_import, count + 1}
      token -> {[token | tokens_to_import], count + 1}
    end
  end

  defp reduce_token(_, _, {tokens, count}), do: {tokens, count + 1}

  @impl Source
  def native_coin_price_history_fetching_enabled?, do: not is_nil(config(:coin_id))

  @impl Source
  def fetch_native_coin_price_history(previous_days), do: do_fetch_coin_price_history(previous_days, false)

  @impl Source
  def secondary_coin_price_history_fetching_enabled?, do: not is_nil(config(:secondary_coin_id))

  @impl Source
  def fetch_secondary_coin_price_history(previous_days), do: do_fetch_coin_price_history(previous_days, true)

  @impl Source
  def market_cap_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_market_cap_history(_previous_days), do: :ignore

  @impl Source
  def tvl_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_tvl_history(_previous_days), do: :ignore

  defp do_fetch_coin(coin_id, coin_id_not_specified_error) do
    with coin_id when not is_nil(coin_id) <- coin_id,
         {:ok, %{"data" => coin}} <-
           Source.http_request(base_url() |> URI.append_path("/currencies/#{coin_id}") |> URI.to_string(), headers()) do
      coin_data = coin["values"][config(:currency)]

      {:ok,
       %Token{
         available_supply: Source.to_decimal(coin["circulatingSupply"]),
         total_supply: Source.to_decimal(coin["totalSupply"]) || Source.to_decimal(coin["circulatingSupply"]),
         btc_value: Source.to_decimal(coin["values"]["BTC"]["price"]),
         last_updated: Source.maybe_get_date(coin["lastUpdated"]),
         market_cap: Source.to_decimal(coin_data["marketCap"]),
         tvl: nil,
         name: coin["name"],
         symbol: String.upcase(coin["symbol"]),
         fiat_value: Source.to_decimal(coin_data["price"]),
         volume_24h: Source.to_decimal(coin_data["volume24h"]),
         image_url: Source.handle_image_url(coin["images"]["60x60"] || coin["images"]["16x16"])
       }}
    else
      nil -> {:error, coin_id_not_specified_error}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("CryptoRank", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  defp do_fetch_coin_price_history(previous_days, secondary_coin?) do
    with coin_id when not is_nil(coin_id) <-
           if(secondary_coin?, do: config(:secondary_coin_id), else: config(:coin_id)),
         from = Date.utc_today() |> Date.add(-previous_days) |> Date.to_iso8601(),
         to = Date.utc_today() |> Date.to_iso8601(),
         {:ok, %{"data" => %{"dates" => dates, "prices" => opening_prices}}} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/currencies/#{coin_id}/sparkline")
             |> URI.append_query("interval=1d")
             |> URI.append_query("from=#{from}")
             |> URI.append_query("to=#{to}")
             |> URI.to_string(),
             headers()
           ) do
      closing_prices =
        case opening_prices do
          [_ | closing_prices] -> closing_prices
          _ -> []
        end

      result =
        [dates, opening_prices, Stream.concat(closing_prices, [nil])]
        |> Enum.zip_with(fn [date, opening_price, closing_price] ->
          date = Source.maybe_get_date(date)

          %{
            closing_price: Source.to_decimal(closing_price) || Source.to_decimal(opening_price),
            date: date && DateTime.to_date(date),
            opening_price: Source.to_decimal(opening_price),
            secondary_coin: secondary_coin?
          }
        end)

      {:ok, result}
    else
      nil -> {:error, "#{Source.secondary_coin_string(secondary_coin?)} ID not specified"}
      {:ok, nil} -> {:ok, []}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("CryptoRank", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  defp base_url do
    if config(:api_key) do
      :base_url |> config() |> URI.parse() |> URI.append_query("api_key=#{config(:api_key)}")
    else
      :base_url |> config() |> URI.parse()
    end
  end

  defp headers do
    []
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__)[key]
  end
end
