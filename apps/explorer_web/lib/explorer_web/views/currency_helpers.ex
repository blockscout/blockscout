defmodule ExplorerWeb.CurrencyHelpers do
  @moduledoc """
  Helper functions for interacting with `t:ExplorerWeb.ExchangeRates.USD.t/0` values.
  """

  import ExplorerWeb.Gettext

  alias ExplorerWeb.ExchangeRates.USD
  alias Cldr.Number

  @doc """
  Formats a `ExplorerWeb.ExchangeRates.USD` value into USD and applies a unit label.

  ## Examples

      iex> format_usd_value(%USD{value: Decimal.new(5)})
      "$5 USD"

      iex> format_usd_value(%USD{value: Decimal.new(5000)})
      "$5,000 USD"

      iex> format_usd_value(%USD{value: Decimal.new(0.000005)})
      "$0.000005 USD"
  """
  @spec format_usd_value(USD.t() | nil) :: binary() | nil
  def format_usd_value(nil), do: nil

  def format_usd_value(%USD{value: nil}), do: nil

  def format_usd_value(%USD{value: value}) do
    case Number.to_string(value, format: "#,##0.##################") do
      {:ok, formatted} -> "$#{formatted} " <> gettext("USD")
      _ -> nil
    end
  end
end
