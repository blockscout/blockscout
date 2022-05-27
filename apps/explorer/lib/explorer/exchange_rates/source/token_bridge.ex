defmodule Explorer.ExchangeRates.Source.TokenBridge do
  @moduledoc """
  Adapter for calculating the market cap and total supply from token bridge
  while still getting other info like price in dollars and bitcoin from a secondary source
  """

  alias Explorer.Chain
  alias Explorer.ExchangeRates.{Source, Token}

  import Source, only: [to_decimal: 1]

  @behaviour Source

  @impl Source
  def format_data(data) do
    data = secondary_source().format_data(data)

    token_data =
      data
      |> Enum.find(fn token -> token.symbol == Explorer.coin() end)
      |> build_struct

    [token_data]
  end

  @impl Source
  def source_url do
    secondary_source().source_url()
  end

  @impl Source
  def source_url(_), do: :ignore

  @impl Source
  def headers do
    []
  end

  defp build_struct(original_token) do
    %Token{
      available_supply: to_decimal(Chain.circulating_supply()),
      total_supply: 0,
      btc_value: original_token.btc_value,
      id: original_token.id,
      last_updated: original_token.last_updated,
      market_cap_usd: market_cap_usd(Chain.circulating_supply(), original_token),
      name: original_token.name,
      symbol: original_token.symbol,
      usd_value: original_token.usd_value,
      volume_24h_usd: original_token.volume_24h_usd
    }
  end

  defp market_cap_usd(nil, _original_token), do: Decimal.new(0)

  defp market_cap_usd(supply, original_token) do
    supply
    |> to_decimal()
    |> Decimal.mult(original_token.usd_value)
  end

  @spec secondary_source() :: module()
  defp secondary_source do
    config(:secondary_source) || Application.get_env(:explorer, Explorer.ExchangeRates.Source)[:source]
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end
end
