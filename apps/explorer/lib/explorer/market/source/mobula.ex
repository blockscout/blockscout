defmodule Explorer.Market.Source.Mobula do
  @moduledoc """
  Adapter for fetching exchange rates from https://mobula.io
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
  def fetch_tokens(nil, batch_size) do
    fetch_tokens(0, batch_size)
  end

  def fetch_tokens(offset, batch_size) do
    with platform_id when not is_nil(platform_id) <- config(:platform),
         {:ok, tokens} when is_list(tokens) <-
           Source.http_request(
             base_url()
             |> URI.append_path("/market/query")
             |> URI.append_query("sortBy=market_cap")
             |> URI.append_query("blockchain=#{platform_id}")
             |> URI.append_query("limit=#{batch_size}")
             |> URI.append_query("offset=#{offset}")
             |> URI.to_string(),
             headers()
           ) do
      {tokens_to_import, initial_tokens_len} =
        Enum.reduce(tokens, {[], 0}, fn token, {to_import, count} ->
          address_hash = token["contracts"] && List.first(token["contracts"])["address"]

          case address_hash && Hash.Address.cast(address_hash) do
            {:ok, token_contract_address_hash} ->
              token_to_import = %{
                symbol: token["symbol"],
                name: token["name"],
                fiat_value: Source.to_decimal(token["price"]),
                volume_24h: Source.to_decimal(token["off_chain_volume"]),
                circulating_market_cap: Source.to_decimal(token["market_cap"]),
                icon_url: Source.handle_image_url(token["logo"]),
                contract_address_hash: token_contract_address_hash,
                type: "ERC-20"
              }

              {[token_to_import | to_import], count + 1}

            _ ->
              {to_import, count + 1}
          end
        end)

      {:ok, offset + batch_size, initial_tokens_len < batch_size, tokens_to_import}
    else
      nil -> {:error, "Platform ID not specified"}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("Mobula", unexpected_response)}
      {:error, _reason} = error -> error
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
  def market_cap_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_market_cap_history(_previous_days), do: :ignore

  @impl Source
  def tvl_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_tvl_history(_previous_days), do: :ignore

  defp do_fetch_coin(coin_id, coin_id_not_specified_error) do
    with coin_id when not is_nil(coin_id) <- coin_id,
         {:ok, %{"data" => data}} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/market/data")
             |> URI.append_query("asset=#{coin_id}")
             |> URI.to_string(),
             headers()
           ) do
      {:ok,
       %Token{
         available_supply: Source.to_decimal(data["circulating_supply"]),
         total_supply: Source.to_decimal(data["total_supply"]) || Source.to_decimal(data["circulating_supply"]),
         btc_value: nil,
         last_updated: nil,
         market_cap: Source.to_decimal(data["market_cap"]),
         tvl: nil,
         name: data["name"],
         symbol: data["symbol"],
         fiat_value: Source.to_decimal(data["price"]),
         volume_24h: Source.to_decimal(data["off_chain_volume"]),
         image_url: Source.handle_image_url(data["logo"])
       }}
    else
      nil ->
        {:error, coin_id_not_specified_error}

      {:ok, unexpected_response} ->
        {:error, Source.unexpected_response_error("Mobula", unexpected_response)}

      {:error, _reason} = error ->
        error
    end
  end

  defp do_fetch_coin_price_history(previous_days, secondary_coin?) do
    with coin_id when not is_nil(coin_id) <-
           if(secondary_coin?, do: config(:secondary_coin_id), else: config(:coin_id)),
         timestamp_ms = (DateTime.utc_now() |> DateTime.add(-previous_days, :day) |> DateTime.to_unix()) * 1000,
         {:ok, %{"data" => %{"price_history" => price_history}}} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/market/history")
             |> URI.append_query("asset=#{coin_id}")
             |> URI.append_query("from=#{timestamp_ms}")
             |> URI.to_string(),
             headers()
           ) do
      result =
        for [date_ms, price] <- price_history do
          %{
            closing_price: Source.to_decimal(price),
            date: Helper.unix_timestamp_to_date(date_ms, :millisecond),
            opening_price: Source.to_decimal(price),
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
    URI.parse(config(:base_url))
  end

  defp headers do
    if config(:api_key) do
      [{"Authorization", "#{config(:api_key)}"}]
    else
      []
    end
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__)[key]
  end
end
