defmodule BlockScoutWeb.ChainView do
  use BlockScoutWeb, :view

  import Number.Currency, only: [number_to_currency: 1, number_to_currency: 2]

  alias BlockScoutWeb.LayoutView
  alias Explorer.Chain.Cache.GasPriceOracle
  alias Explorer.Chain.Supply.TokenBridge

  defp market_cap(:standard, %{available_supply: available_supply, usd_value: usd_value})
       when is_nil(available_supply) or is_nil(usd_value) do
    Decimal.new(0)
  end

  defp market_cap(:standard, %{available_supply: available_supply, usd_value: usd_value}) do
    Decimal.mult(available_supply, usd_value)
  end

  defp market_cap(:standard, exchange_rate) do
    exchange_rate.market_cap_usd
  end

  defp market_cap(module, exchange_rate) do
    module.market_cap(exchange_rate)
  end

  defp total_market_cap_from_token_bridge(%{usd_value: usd_value}) do
    TokenBridge.token_bridge_market_cap(%{usd_value: usd_value})
  end

  defp total_market_cap_from_omni_bridge do
    TokenBridge.total_market_cap_from_omni_bridge()
  end

  defp token_bridge_supply? do
    if System.get_env("SUPPLY_MODULE") === "TokenBridge", do: true, else: false
  end

  def format_usd_value(value) do
    "#{format_currency_value(value)} USD"
  end

  defp format_currency_value(value, symbol \\ "$")

  defp format_currency_value(value, symbol) when value < 0 do
    "#{symbol}0.000000"
  end

  defp format_currency_value(value, symbol) when value < 0.000001 do
    "Less than #{symbol}0.000001"
  end

  defp format_currency_value(value, _symbol) when value < 1 do
    "#{number_to_currency(value, precision: 6)}"
  end

  defp format_currency_value(value, _symbol) when value < 100_000 do
    "#{number_to_currency(value)}"
  end

  defp format_currency_value(value, symbol) when value >= 1_000_000 and value <= 999_000_000 do
    {:ok, value} = Cldr.Number.to_string(value, format: :short, currency: :USD, fractional_digits: 2)
    value
  end

  defp format_currency_value(value, symbol) do
    "#{number_to_currency(value, precision: 0)}"
  end

  defp gas_prices do
    case GasPriceOracle.get_gas_prices() do
      {:ok, gas_prices} ->
        gas_prices

      nil ->
        nil

      _ ->
        nil
    end
  end
end
