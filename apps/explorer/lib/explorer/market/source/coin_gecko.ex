# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Market.Source.CoinGecko do
  @moduledoc """
  Adapter for fetching exchange rates from https://coingecko.com
  """

  alias Explorer.Chain.Hash
  alias Explorer.Market.{Source, Token}

  @behaviour Source

  # CoinGecko rejects `/coins/markets` requests with `per_page` above 250, so a
  # larger configured batch size is capped here and processed across several requests.
  @coins_markets_max_per_page 250

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

      tokens_to_fetch when is_list(tokens_to_fetch) and tokens_to_fetch !== [] ->
        fetch_tokens(tokens_to_fetch, batch_size)

      _ ->
        {:error, "Tokens not found for configured platform: #{config(:platform)}"}
    end
  end

  @impl Source
  def fetch_tokens(state, batch_size) do
    per_page = min(batch_size, @coins_markets_max_per_page)
    {to_fetch, remaining} = Enum.split(state, per_page)

    joined_token_ids = Enum.map_join(to_fetch, ",", & &1.id)

    case Source.http_request(
           base_url()
           |> URI.append_path("/coins/markets")
           |> URI.append_query("vs_currency=#{config(:currency)}")
           |> URI.append_query("ids=#{joined_token_ids}")
           |> URI.append_query("per_page=#{per_page}")
           |> URI.append_query("page=1")
           |> URI.to_string(),
           headers(),
           __MODULE__,
           :coins_markets
         ) do
      {:ok, data} when is_list(data) ->
        to_import = put_market_data_to_tokens(to_fetch, data)
        {:ok, remaining, Enum.empty?(remaining), to_import}

      {:ok, unexpected_response} ->
        {:error, Source.unexpected_response_error("CoinGecko", unexpected_response)}

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
         {:ok, %{"market_caps" => market_caps}} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/coins/#{coin_id}/market_chart")
             |> URI.append_query("vs_currency=#{config(:currency)}")
             |> URI.append_query("days=#{previous_days}")
             |> URI.to_string(),
             headers(),
             __MODULE__,
             :coins_market_chart_market_cap
           ) do
      result =
        for %{date: date, closing: market_cap} <- fold_into_daily_records(market_caps) do
          %{market_cap: market_cap, date: date}
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
             headers(),
             __MODULE__,
             :coins_details
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
         image_url: Source.handle_image_url(data["image"]["small"] || data["image"]["thumb"]),
         circulating_supply: Source.to_decimal(market_data["circulating_supply"])
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
             headers(),
             __MODULE__,
             :coins_list
           ) do
      tokens
      |> Enum.reduce([], &reduce_coingecko_token(&1, &2, platform))
    else
      nil -> {:error, "Platform not specified"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp reduce_coingecko_token(
         %{
           "id" => id,
           "symbol" => symbol,
           "name" => name,
           "platforms" => platforms
         },
         acc,
         platform
       ) do
    case Map.get(platforms, platform) do
      nil ->
        acc

      token_contract_address_hash_string ->
        case Hash.Address.cast(token_contract_address_hash_string) do
          {:ok, token_contract_address_hash} ->
            [build_coingecko_token(id, symbol, name, token_contract_address_hash) | acc]

          _ ->
            acc
        end
    end
  end

  defp reduce_coingecko_token(_, acc, _platform), do: acc

  defp build_coingecko_token(id, symbol, name, token_contract_address_hash) do
    %{
      id: id,
      symbol: symbol,
      name: name,
      contract_address_hash: token_contract_address_hash,
      type: "ERC-20"
    }
  end

  defp put_market_data_to_tokens(tokens, market_data) do
    # /coins/markets returns an array of coin objects, each carrying its "id".
    # Note: `total_supply` from the response is intentionally not imported: `Token.total_supply`
    # holds the raw on-chain `totalSupply()` value maintained by the token total supply fetchers,
    # while CoinGecko reports a unit-scaled amount.
    market_data_map = Map.new(market_data, &{&1["id"], &1})

    tokens
    |> Enum.reduce([], fn token, to_import ->
      case Map.fetch(market_data_map, token.id) do
        {:ok, coin_data} ->
          token_with_market_data =
            Map.merge(token, %{
              fiat_value: Source.to_decimal(coin_data["current_price"]),
              circulating_market_cap: Source.to_decimal(coin_data["market_cap"]),
              volume_24h: Source.to_decimal(coin_data["total_volume"]),
              circulating_supply: Source.to_decimal(coin_data["circulating_supply"])
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
             headers(),
             __MODULE__,
             :coins_market_chart_price
           ) do
      result =
        for %{date: date, opening: opening_price, closing: closing_price} <- fold_into_daily_records(prices) do
          %{
            closing_price: closing_price,
            date: date,
            opening_price: opening_price,
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

  # `/coins/{id}/market_chart` returns one point per day (at 00:00 UTC) only for
  # ranges longer than 90 days. Shorter ranges, including the periodic `days=1`
  # refetch of the history fetcher, come with hourly or 5-minute granularity, so the
  # points are folded into a single record per UTC date here:
  #
  #   * `opening` is the first value of the date;
  #   * `closing` is the first value of the next date, or the last value of the
  #     range for its latest date (CoinGecko appends the current value as the last
  #     point, so this is the live price for today).
  #
  # The opening value of the earliest date is only known when the range starts at
  # the beginning of that date. A range starting mid-day (e.g. the `days=1` refetch
  # covers the last 24 hours) yields `nil` instead, so that the value already stored
  # in `market_history` is kept by the upsert.
  @day_start_tolerance ~T[01:00:00]

  @spec fold_into_daily_records([[number() | nil]]) :: [
          %{date: Date.t(), opening: Decimal.t() | nil, closing: Decimal.t()}
        ]
  defp fold_into_daily_records(points) when is_list(points) do
    points
    |> Enum.flat_map(fn
      [timestamp, value] when is_integer(timestamp) and not is_nil(value) ->
        [{DateTime.from_unix!(timestamp, :millisecond), Source.to_decimal(value)}]

      _ ->
        []
    end)
    |> Enum.sort_by(fn {datetime, _value} -> datetime end, DateTime)
    |> Enum.chunk_by(fn {datetime, _value} -> DateTime.to_date(datetime) end)
    |> fold_daily_chunks(true, [])
  end

  defp fold_into_daily_records(_points), do: []

  defp fold_daily_chunks([], _earliest?, acc), do: Enum.reverse(acc)

  defp fold_daily_chunks([[{first_datetime, first_value} | _] = chunk | rest], earliest?, acc) do
    closing =
      case rest do
        [[{_next_datetime, next_first_value} | _] | _] -> next_first_value
        [] -> chunk |> List.last() |> elem(1)
      end

    opening =
      if earliest? and not day_start?(first_datetime) do
        nil
      else
        first_value
      end

    record = %{date: DateTime.to_date(first_datetime), opening: opening, closing: closing}

    fold_daily_chunks(rest, false, [record | acc])
  end

  defp day_start?(datetime) do
    datetime
    |> DateTime.to_time()
    |> Time.compare(@day_start_tolerance) == :lt
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
