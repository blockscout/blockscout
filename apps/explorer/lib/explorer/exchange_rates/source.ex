defmodule Explorer.ExchangeRates.Source do
  @moduledoc """
  Behaviour for fetching exchange rates from external sources.
  """

  alias Explorer.ExchangeRates.Token

  @doc """
  Callback for fetching an exchange rates for currencies/tokens.
  """
  @callback fetch_exchange_rates :: {:ok, [Token.t()]} | {:error, any}

  def headers do
    [{"Content-Type", "application/json"}]
  end

  def decode_json(data) do
    Jason.decode!(data)
  end

  def to_decimal(nil), do: nil

  def to_decimal(value) do
    Decimal.new(value)
  end
end
