defmodule Explorer.ExchangeRates.Source do
  @moduledoc """
  Behaviour for fetching exchange rates from external sources.
  """

  alias Explorer.ExchangeRates.Rate

  @doc """
  Callback for fetching an exchange rate for a given cryptocurrency.
  """
  @callback fetch_exchange_rate(ticker :: String.t()) :: {:ok, Rate.t()} | {:error, any}
end
