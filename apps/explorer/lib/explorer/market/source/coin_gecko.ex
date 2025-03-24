defmodule Explorer.Market.Source.CoinGecko do
  @moduledoc """
  Adapter for fetching exchange rates from https://coingecko.com
  """

  alias Explorer.Chain.Hash
  alias Explorer.Helper
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
  def fetch_tokens(state, batch_size) when state in [[], nil] do
    case init_tokens_fetching() do
      {:error, _reason} = error ->
        error

      tokens_to_fetch when is_list(tokens_to_fetch) and length(tokens_to_fetch) > 0 ->
        fetch_tokens(tokens_to_fetch, batch_size)

      _ ->
        {:error, "Tokens not found for configured platform: #{config(:platform)}"}
    end
  end

  @impl Source
  def fetch_tokens(state, batch_size) do
    {to_fetch, remaining} = Enum.split(state, batch_size)

    joined_token_ids = Enum.map_join(to_fetch, ",", & &1.id)

    case Source.http_request(
           base_url()
           |> URI.append_path("/simple/price")
           |> URI.append_query("vs_currencies=#{config(:currency)}")
           |> URI.append_query("include_market_cap=true")
           |> URI.append_query("include_24hr_vol=true")
           |> URI.append_query("ids=#{joined_token_ids}")
           |> URI.to_string(),
           headers()
         ) do
      {:ok, data} ->
        to_import = put_market_data_to_tokens(to_fetch, data)
        {:ok, remaining, Enum.empty?(remaining), to_import}

      {:error, _reason} = error ->
        error
    end
  end

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
    with coin_id when not is_nil(coin_id) <- config(:coin_id),
         {:ok, %{"market_caps" => market_caps_dates}} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/coins/#{coin_id}/market_chart")
             |> URI.append_query("vs_currency=#{config(:currency)}")
             |> URI.append_query("days=#{previous_days}")
             |> URI.to_string(),
             headers()
           ) do
      market_caps =
        case market_caps_dates do
          [_ | market_caps] -> market_caps
          _ -> []
        end

      result =
        for {[_, market_cap], [date, _]} <- Stream.zip(market_caps, market_caps_dates) do
          %{
            market_cap: Source.to_decimal(market_cap),
            date: Helper.unix_timestamp_to_date(date, :millisecond)
          }
        end

      {:ok, result}
    else
      nil -> {:error, "Coin ID not specified"}
      {:ok, nil} -> {:ok, []}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("CoinGecko", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  @impl Source
  def tvl_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_tvl_history(_previous_days), do: :ignore

  defp do_fetch_coin(coin_id, coin_id_not_specified_error) do
    with coin_id when not is_nil(coin_id) <- coin_id,
         {:ok, %{"market_data" => market_data} = data} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/coins/#{coin_id}")
             |> URI.append_query("localization=false")
             |> URI.append_query("tickers=false")
             |> URI.append_query("market_data=true")
             |> URI.append_query("community_data=false")
             |> URI.append_query("developer_data=false")
             |> URI.append_query("sparkline=false")
             |> URI.to_string(),
             headers()
           ) do
      {:ok,
       %Token{
         available_supply: Source.to_decimal(market_data["circulating_supply"]),
         total_supply:
           Source.to_decimal(market_data["total_supply"]) || Source.to_decimal(market_data["circulating_supply"]),
         btc_value: Source.to_decimal(market_data["current_price"]["btc"]),
         last_updated: Source.maybe_get_date(market_data["last_updated"]),
         market_cap: Source.to_decimal(market_data["market_cap"][config(:currency)]),
         tvl: nil,
         name: data["name"],
         symbol: String.upcase(data["symbol"]),
         fiat_value: Source.to_decimal(market_data["current_price"][config(:currency)]),
         volume_24h: Source.to_decimal(market_data["total_volume"][config(:currency)]),
         image_url: Source.handle_image_url(data["image"]["small"] || data["image"]["thumb"])
       }}
    else
      nil -> {:error, coin_id_not_specified_error}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("CoinGecko", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  defp init_tokens_fetching do
    with platform when not is_nil(platform) <- config(:platform),
         {:ok, tokens} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/coins/list")
             |> URI.append_query("include_platform=true")
             |> URI.to_string(),
             headers()
           ) do
      tokens
      |> Enum.reduce([], fn
        %{
          "id" => id,
          "symbol" => symbol,
          "name" => name,
          "platforms" => %{
            ^platform => token_contract_address_hash_string
          }
        },
        acc ->
          case Hash.Address.cast(token_contract_address_hash_string) do
            {:ok, token_contract_address_hash} ->
              token = %{
                id: id,
                symbol: symbol,
                name: name,
                contract_address_hash: token_contract_address_hash,
                type: "ERC-20"
              }

              [token | acc]

            _ ->
              acc
          end

        _, acc ->
          acc
      end)
    else
      nil -> {:error, "Platform not specified"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_market_data_to_tokens(tokens, market_data) do
    currency = config(:currency)
    market_cap = currency <> "_market_cap"
    volume_24h = currency <> "_24h_vol"

    tokens
    |> Enum.reduce([], fn token, to_import ->
      case Map.fetch(market_data, token.id) do
        {:ok, %{^currency => fiat_value, ^market_cap => market_cap, ^volume_24h => volume_24h}} ->
          token_with_market_data =
            Map.merge(token, %{
              fiat_value: Source.to_decimal(fiat_value),
              circulating_market_cap: Source.to_decimal(market_cap),
              volume_24h: Source.to_decimal(volume_24h)
            })

          [token_with_market_data | to_import]

        _ ->
          to_import
      end
    end)
  end

  defp do_fetch_coin_price_history(previous_days, secondary_coin?) do
    with coin_id when not is_nil(coin_id) <-
           if(secondary_coin?, do: config(:secondary_coin_id), else: config(:coin_id)),
         {:ok, %{"prices" => prices}} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/coins/#{coin_id}/market_chart")
             |> URI.append_query("vs_currency=#{config(:currency)}")
             |> URI.append_query("days=#{previous_days}")
             |> URI.to_string(),
             headers()
           ) do
      closings =
        case prices do
          [_ | closings] -> closings
          _ -> []
        end

      result =
        for {[date, opening_price], [_, closing_price]} <- Stream.zip(prices, closings) do
          %{
            closing_price: Source.to_decimal(closing_price),
            date: Helper.unix_timestamp_to_date(date, :millisecond),
            opening_price: Source.to_decimal(opening_price) || Source.to_decimal(closing_price),
            secondary_coin: secondary_coin?
          }
        end

      {:ok, result}
    else
      nil -> {:error, "#{Source.secondary_coin_string(secondary_coin?)} ID not specified"}
      {:ok, nil} -> {:ok, []}
      {:error, _reason} = error -> error
    end
  end

  defp base_url do
    :api_key
    |> config()
    |> if do
      config(:base_pro_url)
    else
      config(:base_url)
    end
    |> URI.parse()
  end

  defp headers do
    if config(:api_key) do
      case config(:base_pro_url) do
        "https://api.coingecko.com" <> _ ->
          [{"X-Cg-Demo-Api-Key", "#{config(:api_key)}"}]

        _ ->
          [{"X-Cg-Pro-Api-Key", "#{config(:api_key)}"}]
      end
    else
      []
    end
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__)[key]
  end
end
