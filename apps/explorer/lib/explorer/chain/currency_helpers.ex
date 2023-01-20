defmodule Explorer.Chain.CurrencyHelpers do
  @moduledoc """
  Helper functions for interacting with `t:BlockScoutWeb.ExchangeRates.USD.t/0` values.
  """

  alias Explorer.CldrHelper.Number

  @doc """
  Formats the given integer value to a currency format.

  ## Examples

      iex> BlockScoutWeb.CurrencyHelpers.format_integer_to_currency(1000000)
      "1,000,000"
  """
  @spec format_integer_to_currency(non_neg_integer() | nil) :: String.t()
  def format_integer_to_currency(value)

  def format_integer_to_currency(nil) do
    "-"
  end

  def format_integer_to_currency(value) do
    {:ok, formatted} = Number.to_string(value, format: "#,##0")

    formatted
  end

  @doc """
  Formats the given amount according to given decimals.

  ## Examples

      iex> format_according_to_decimals(nil, Decimal.new(5))
      "-"

      iex> format_according_to_decimals(Decimal.new(20500000), Decimal.new(5))
      "205"

      iex> format_according_to_decimals(Decimal.new(20500000), Decimal.new(7))
      "2.05"

      iex> format_according_to_decimals(Decimal.new(205000), Decimal.new(12))
      "0.000000205"

      iex> format_according_to_decimals(Decimal.new(205000), Decimal.new(2))
      "2,050"

      iex> format_according_to_decimals(205000, Decimal.new(2))
      "2,050"

      iex> format_according_to_decimals(105000, Decimal.new(0))
      "105,000"

      iex> format_according_to_decimals(105000000000000000000, Decimal.new(100500))
      "105"

      iex> format_according_to_decimals(105000000000000000000, nil)
      "105,000,000,000,000,000,000"
  """
  @spec format_according_to_decimals(non_neg_integer() | nil, nil) :: String.t()
  def format_according_to_decimals(nil, _) do
    "-"
  end

  def format_according_to_decimals(value, nil) do
    format_according_to_decimals(value, Decimal.new(0))
  end

  def format_according_to_decimals(value, decimals) when is_integer(value) do
    value
    |> Decimal.new()
    |> format_according_to_decimals(decimals)
  end

  @spec format_according_to_decimals(Decimal.t(), Decimal.t()) :: String.t()
  def format_according_to_decimals(value, decimals) do
    if Decimal.compare(decimals, 24) == :gt do
      format_according_to_decimals(value, Decimal.new(18))
    else
      value
      |> divide_decimals(decimals)
      |> thousands_separator()
    end
  end

  defp thousands_separator(value) do
    if Decimal.to_float(value) > 999 do
      Number.to_string!(value)
    else
      Decimal.to_string(value, :normal)
    end
  end

  @spec divide_decimals(Decimal.t(), Decimal.t()) :: Decimal.t()
  def divide_decimals(%{sign: sign, coef: coef, exp: exp}, decimals) do
    sign
    |> Decimal.new(coef, exp - Decimal.to_integer(decimals))
    |> Decimal.normalize()
  end
end
