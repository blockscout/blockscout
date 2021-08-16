defmodule Explorer.Chain.CurrencyHelpers do
  @moduledoc """
  Helper functions for interacting with `t:BlockScoutWeb.ExchangeRates.USD.t/0` values.
  """

  @spec divide_decimals(Decimal.t(), Decimal.t()) :: Decimal.t()
  def divide_decimals(%{sign: sign, coef: coef, exp: exp}, decimals) do
    sign
    |> Decimal.new(coef, exp - Decimal.to_integer(decimals))
    |> Decimal.normalize()
  end
end
