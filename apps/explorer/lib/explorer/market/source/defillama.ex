# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Market.Source.DefiLlama do
  @moduledoc """
  Adapter for fetching market history from https://defillama.com/.

  Requests go to the free API by default. When `MARKET_DEFILLAMA_API_KEY` is
  set, requests are sent to the Pro API instead. DefiLlama expects the key as a
  path segment between the Pro host and the endpoint
  (`https://pro-api.llama.fi/{API_KEY}/api/v2/...`), not as a header or query
  parameter, so the key never appears in request headers.
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
  def native_coin_price_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_native_coin_price_history(_previous_days), do: :ignore

  @impl Source
  def secondary_coin_price_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_secondary_coin_price_history(_previous_days), do: :ignore

  @impl Source
  def market_cap_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_market_cap_history(_previous_days), do: :ignore

  @impl Source
  def tvl_history_fetching_enabled?, do: not is_nil(config(:coin_id))

  @impl Source
  def fetch_tvl_history(_previous_days) do
    with coin_id when not is_nil(coin_id) <- config(:coin_id),
         {:ok, data} when is_list(data) <-
           Source.http_request(
             base_url() |> URI.append_path("/historicalChainTvl/#{URI.encode(coin_id)}") |> URI.to_string(),
             headers(),
             __MODULE__,
             :historical_chain_tvl
           ) do
      result =
        Enum.map(data, fn %{"date" => date, "tvl" => tvl} ->
          %{
            tvl: Source.to_decimal(tvl),
            date: Helper.unix_timestamp_to_date(date)
          }
        end)

      {:ok, result}
    else
      nil -> {:error, "Coin ID not specified"}
      {:ok, nil} -> {:ok, []}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("DefiLlama", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  # Free API: `<base_url>/historicalChainTvl/...`.
  # Pro API:  `<pro_base_url>/<api_key>/api/v2/historicalChainTvl/...`.
  @spec base_url() :: URI.t()
  defp base_url do
    case config(:api_key) do
      api_key when api_key in [nil, ""] ->
        URI.parse(config(:base_url))

      api_key ->
        config(:pro_base_url)
        |> URI.parse()
        |> URI.append_path("/#{URI.encode(api_key)}/api/v2")
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
