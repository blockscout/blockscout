defmodule Explorer.Market.Source.CryptoCompare do
  @moduledoc """
  Adapter for fetching market history from https://cryptocompare.com.
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
  def native_coin_price_history_fetching_enabled?, do: not is_nil(config(:coin_symbol))

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
    with coin_symbol when not is_nil(coin_symbol) <-
           if(secondary_coin?, do: config(:secondary_coin_symbol), else: config(:coin_symbol)),
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
             headers()
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

  defp headers do
    if config(:api_key) do
      [{"Authorization", "Apikey #{config(:api_key)}"}]
    else
      []
    end
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__)[key]
  end
end
