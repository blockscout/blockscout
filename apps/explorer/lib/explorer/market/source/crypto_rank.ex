# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Market.Source.CryptoRank do
  @moduledoc """
  Adapter for fetching market history from https://cryptorank.io/.

  Native/secondary coin data and price history are fetched from the public
  v3 API (`/v3/currencies/:id` and `/v3/currencies/:id/sparkline`), which is
  authenticated with the `X-Api-Key` header.

  Tokens are fetched from the dedicated Blockscout endpoint
  (`/v1/dedicated/blockscout/currencies/contracts/:platform_id`), which is not
  part of the public API and is only served under v1 with the `api_key` query
  parameter.

  `base_url` must therefore point at the API host without a version segment
  (`https://api.cryptorank.io` by default); a trailing `/v1` is stripped for
  backwards compatibility.
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
             dedicated_url("/currencies/contracts/#{platform_id}")
             |> URI.append_query("limit=#{batch_size}")
             |> URI.append_query("skip=#{skip}")
             |> URI.to_string(),
             [],
             __MODULE__,
             :currencies_contracts
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
              circulating_supply: circulating_supply,
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
         {:ok, %{"data" => coin} = response} when is_map(coin) <-
           Source.http_request(
             v3_url("/currencies/#{coin_id}")
             |> URI.append_query("convert=#{config(:currency)}")
             |> URI.to_string(),
             headers(),
             __MODULE__,
             :currencies_details
           ) do
      circulating_supply = Source.to_decimal(coin["circulatingSupply"])

      {:ok,
       %Token{
         available_supply: circulating_supply,
         total_supply: Source.to_decimal(coin["totalSupply"]) || circulating_supply,
         # v3 returns prices in fiat only (`convert` accepts USD/EUR), no BTC quote
         btc_value: nil,
         # the profile carries no update timestamp, use the response time instead
         last_updated: unix_ms_to_datetime(get_in(response, ["status", "timestamp"])),
         market_cap: Source.to_decimal(coin["marketCap"]),
         tvl: nil,
         name: coin["name"],
         symbol: coin["symbol"] && String.upcase(coin["symbol"]),
         fiat_value: Source.to_decimal(coin["price"]),
         volume_24h: Source.to_decimal(coin["volume24h"]),
         image_url: Source.handle_image_url(coin["imageUrl"]),
         circulating_supply: circulating_supply
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
         {:ok, %{"data" => points}} when is_list(points) <-
           Source.http_request(
             v3_url("/currencies/#{coin_id}/sparkline")
             |> URI.append_query("interval=1d")
             |> URI.append_query("from=#{from}")
             |> URI.append_query("to=#{to}")
             |> URI.append_query("sortOrder=asc")
             |> URI.to_string(),
             headers(),
             __MODULE__,
             :currencies_sparkline
           ) do
      result =
        points
        |> Enum.map(fn point -> {point["time"], Source.to_decimal(point["price"])} end)
        |> Enum.chunk_every(2, 1)
        |> Enum.map(fn
          [{time, opening_price}, {_next_time, closing_price}] ->
            price_history_entry(time, opening_price, closing_price, secondary_coin?)

          [{time, opening_price}] ->
            price_history_entry(time, opening_price, nil, secondary_coin?)
        end)

      {:ok, result}
    else
      nil -> {:error, "#{Source.secondary_coin_string(secondary_coin?)} ID not specified"}
      {:ok, nil} -> {:ok, []}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("CryptoRank", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  defp price_history_entry(time, opening_price, closing_price, secondary_coin?) do
    datetime = unix_ms_to_datetime(time)

    %{
      closing_price: closing_price || opening_price,
      date: datetime && DateTime.to_date(datetime),
      opening_price: opening_price,
      secondary_coin: secondary_coin?
    }
  end

  @spec unix_ms_to_datetime(term()) :: DateTime.t() | nil
  defp unix_ms_to_datetime(timestamp) when is_integer(timestamp) do
    case DateTime.from_unix(timestamp, :millisecond) do
      {:ok, datetime} -> datetime
      _ -> nil
    end
  end

  defp unix_ms_to_datetime(_), do: nil

  defp v3_url(path) do
    base_url() |> URI.append_path("/v3" <> path)
  end

  defp dedicated_url(path) do
    url = base_url() |> URI.append_path("/v1/dedicated/blockscout" <> path)

    if config(:api_key) do
      URI.append_query(url, "api_key=#{config(:api_key)}")
    else
      url
    end
  end

  # Strips a trailing version segment (e.g. `/v1`, the previous default) and
  # trailing slash so that overrides of `base_url` cannot produce duplicated or
  # stale version segments; the version is appended per endpoint.
  defp base_url do
    :base_url
    |> config()
    |> String.replace(~r{(/v\d+)?/*$}, "")
    |> URI.parse()
  end

  defp headers do
    if config(:api_key), do: [{"X-Api-Key", "#{config(:api_key)}"}], else: []
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__)[key]
  end
end
