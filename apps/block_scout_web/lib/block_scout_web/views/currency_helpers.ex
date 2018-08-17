defmodule BlockScoutWeb.CurrencyHelpers do
  @moduledoc """
  Helper functions for interacting with `t:BlockScoutWeb.ExchangeRates.USD.t/0` values.
  """

  import BlockScoutWeb.Gettext

  alias BlockScoutWeb.ExchangeRates.USD
  alias BlockScoutWeb.Cldr

  @doc """
  Formats a `BlockScoutWeb.ExchangeRates.USD` value into USD and applies a unit label.

  ## Examples

      iex> format_usd_value(%USD{value: Decimal.new(5)})
      "$5.00 USD"

      iex> format_usd_value(%USD{value: Decimal.new(5000)})
      "$5,000.00 USD"

      iex> format_usd_value(%USD{value: Decimal.new(0.000005)})
      "$0.000005 USD"
  """
  @spec format_usd_value(USD.t() | nil) :: binary() | nil
  def format_usd_value(nil), do: nil

  def format_usd_value(%USD{value: nil}), do: nil

  def format_usd_value(%USD{value: value}) do
    case Cldr.Number.to_string(value, format: "#,##0.00################") do
      {:ok, formatted} -> "$#{formatted} " <> gettext("USD")
      _ -> nil
    end
  end

  @doc """
  Formats the given integer value to a currency format.

  ## Examples

      iex> BlockScoutWeb.CurrencyHelpers.format_integer_to_currency(1000000)
      "1,000,000"
  """
  @spec format_integer_to_currency(non_neg_integer()) :: String.t()
  def format_integer_to_currency(value) do
    {:ok, formatted} = Cldr.Number.to_string(value, format: "#,##0")

    formatted
  end

  @doc """
  Formats the given amount according to given decimals.

  ## Examples

      iex> format_according_to_decimals(Decimal.new(20500000), 5)
      "205"

      iex> format_according_to_decimals(Decimal.new(20500000), 7)
      "2.05"

      iex> format_according_to_decimals(Decimal.new(205000), 12)
      "0.000000205"

      iex> format_according_to_decimals(Decimal.new(205000), 2)
      "2,050"

      iex> format_according_to_decimals(205000, 2)
      "2,050"
  """
  @spec format_according_to_decimals(non_neg_integer(), non_neg_integer()) :: String.t()
  def format_according_to_decimals(value, nil) do
    format_according_to_decimals(value, 0)
  end

  def format_according_to_decimals(value, decimals) when is_integer(value) do
    value
    |> Decimal.new()
    |> format_according_to_decimals(decimals)
  end

  @spec format_according_to_decimals(Decimal.t(), non_neg_integer()) :: String.t()
  def format_according_to_decimals(%Decimal{sign: sign, coef: coef, exp: exp}, decimals) do
    sign
    |> Decimal.new(coef, exp - decimals)
    |> Decimal.reduce()
    |> thousands_separator()
  end

  defp thousands_separator(value) do
    if Decimal.to_float(value) > 999 do
      Cldr.Number.to_string!(value)
    else
      Decimal.to_string(value, :normal)
    end
  end
end
