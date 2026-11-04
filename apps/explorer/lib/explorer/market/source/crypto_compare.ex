# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Market.Source.CryptoCompare do
  @moduledoc """
  Adapter for fetching market history from https://cryptocompare.com.

  The source is opt-in: it is auto-selected for native coin price history only
  when `MARKET_CRYPTOCOMPARE_COIN_SYMBOL` or `MARKET_CRYPTOCOMPARE_API_KEY` is
  set, since the CryptoCompare API requires an API key. When the source is chosen
  explicitly (`MARKET_NATIVE_COIN_HISTORY_SOURCE=crypto_compare`) or enabled via
  the API key alone, the native coin symbol falls back to `COIN`.
  """

  alias Explorer.Helper
  alias Explorer.Market.Source

  @behaviour Source

  @impl Source
  def native_coin_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_native_coin, do: :ignore

  @impl Source
  def secondary_coin_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_secondary_coin, do: :ignore

  @impl Source
  def tokens_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_tokens(_state, _batch_size), do: :ignore

  @impl Source
  def native_coin_price_history_fetching_enabled?, do: not is_nil(config(:coin_symbol)) or api_key_configured?()

  @impl Source
  def fetch_native_coin_price_history(previous_days), do: do_fetch_coin_price_history(previous_days, false)

  @impl Source
  def secondary_coin_price_history_fetching_enabled?, do: not is_nil(config(:secondary_coin_symbol))

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

  defp do_fetch_coin_price_history(previous_days, secondary_coin?) do
    with coin_symbol when not is_nil(coin_symbol) <- coin_symbol(secondary_coin?),
         {:ok, %{"Data" => %{"Data" => data}}} <-
           Source.http_request(
             :base_url
             |> config()
             |> URI.parse()
             |> URI.append_path("/data/v2/histoday")
             |> URI.append_query("fsym=#{coin_symbol}")
             |> URI.append_query("limit=#{previous_days}")
             |> URI.append_query("tsym=#{config(:currency)}")
             |> URI.append_query("extraParams=Blockscout/#{Application.spec(:explorer)[:vsn]}")
             |> URI.to_string(),
             headers(),
             __MODULE__,
             :data_histoday
           ) do
      result =
        for item <- data do
          %{
            closing_price: Source.to_decimal(item["close"]),
            date: Helper.unix_timestamp_to_date(item["time"]),
            opening_price: Source.to_decimal(item["open"]),
            secondary_coin: secondary_coin?
          }
        end

      {:ok, result}
    else
      nil -> {:error, "#{Source.secondary_coin_string(secondary_coin?)} ID not specified"}
      {:ok, nil} -> {:ok, []}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("CryptoCompare", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  # The native coin symbol falls back to the chain's `COIN` so that explicit
  # `MARKET_NATIVE_COIN_HISTORY_SOURCE=crypto_compare` setups keep working without
  # `MARKET_CRYPTOCOMPARE_COIN_SYMBOL`. There is no such fallback for the secondary
  # coin.
  @spec coin_symbol(boolean()) :: String.t() | nil
  defp coin_symbol(true), do: config(:secondary_coin_symbol)
  defp coin_symbol(false), do: config(:coin_symbol) || Application.get_env(:explorer, :coin)

  defp headers do
    if api_key_configured?(), do: [{"Authorization", "Apikey #{config(:api_key)}"}], else: []
  end

  @spec api_key_configured?() :: boolean()
  defp api_key_configured?, do: config(:api_key) not in [nil, ""]

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__)[key]
  end
end
