defmodule BlockScoutWeb.CurrencyHelpers do
  @moduledoc """
  Helper functions for interacting with `t:BlockScoutWeb.ExchangeRates.USD.t/0` values.
  """

  alias BlockScoutWeb.CldrHelper.Number

  @doc """
  Formats the given integer value to a currency format.

  ## Examples

      iex> BlockScoutWeb.CurrencyHelpers.format_integer_to_currency(1000000)
      "1,000,000"
  """
  @spec format_integer_to_currency(non_neg_integer()) :: String.t()
  def format_integer_to_currency(value) do
    {:ok, formatted} = Number.to_string(value, format: "#,##0")

    formatted
  end

  @doc """
  Formats the given amount according to given decimals.

  ## Examples

      iex> format_according_to_decimals(nil, Decimal.new(5), "USDC")
      "-"

      iex> format_according_to_decimals(Decimal.new(20500000), Decimal.new(5), "USDC")
      "205"

      iex> format_according_to_decimals(Decimal.new(20500000), Decimal.new(7), "USDC")
      "2.05"

      iex> format_according_to_decimals(Decimal.new(205000), Decimal.new(12), "USDC")
      "0.000000205"

      iex> format_according_to_decimals(Decimal.new(205000), Decimal.new(2), "USDC")
      "2,050"

      iex> format_according_to_decimals(205000, Decimal.new(2), "USDC")
      "2,050"
  """
  @spec format_according_to_decimals(non_neg_integer() | nil, nil, nil) :: String.t()
  def format_according_to_decimals(nil, _, _) do
    "-"
  end

  def format_according_to_decimals(value, nil, nil) do
    format_according_to_decimals(value, Decimal.new(0), "TOKEN")
  end

  def format_according_to_decimals(value, nil, symbol) when is_binary(symbol) do
    format_according_to_decimals(value, Decimal.new(0), symbol)
  end

  def format_according_to_decimals(value, decimals, nil) when is_integer(value) do
    format_according_to_decimals(Decimal.new(value), decimals, "TOKEN")
  end

  def format_according_to_decimals(value, decimals, symbol) when is_integer(value) and is_binary(symbol) do
    if symbol == "USDC" || symbol === "USDT" do
      format_according_to_decimals(Decimal.new(6), decimals, symbol)
    else
      format_according_to_decimals(Decimal.new(value), decimals, symbol)
    end
  end

  @spec format_according_to_decimals(Decimal.t(), Decimal.t(), String.t()) :: String.t()
  def format_according_to_decimals(value, decimals, symbol) do
    if symbol == "USDC" || symbol === "USDT" do
      value
      |> divide_decimals(Decimal.new(6))
      |> thousands_separator()
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
