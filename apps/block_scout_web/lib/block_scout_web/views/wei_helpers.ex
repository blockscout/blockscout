defmodule BlockScoutWeb.WeiHelpers do
  @moduledoc """
  Helper functions for interacting with `t:Explorer.Chain.Wei.t/0` values.
  """

  import BlockScoutWeb.Gettext

  alias BlockScoutWeb.CldrHelper
  alias Explorer.Chain.Wei

  @valid_units ~w(wei gwei ether)a

  @type format_option :: {:include_unit_label, boolean()}

  @type format_options :: [format_option()]

  @doc """
  Converts a `t:Explorer.Wei.t/0` value to the specified unit including a
  translated unit label.

  ## Supported Formatting Options

  The third argument allows for keyword options to be passed for formatting the
  converted number.

    * `:include_unit_label` - Boolean (Defaults to `true`). Flag for if the unit
      label should be included in the returned string

  ## Examples

      iex> format_wei_value(%Wei{value: Decimal.new(1)}, :wei)
      "1 Wei"

      iex> format_wei_value(%Wei{value: Decimal.new(1, 10, 12)}, :gwei)
      "10,000 Gwei"

      iex> format_wei_value(%Wei{value: Decimal.new(1, 10, 21)}, :ether)
      "10,000 Ether"

      # With formatting options

      iex> format_wei_value(
      ...>   %Wei{value: Decimal.new(1000500000000000000)},
      ...>   :ether
      ...> )
      "1.0005 Ether"

      iex> format_wei_value(
      ...>   %Wei{value: Decimal.new(10)},
      ...>   :wei,
      ...>   include_unit_label: false
      ...> )
      "10"
  """
  @spec format_wei_value(Wei.t(), Wei.unit(), format_options()) :: String.t()
  def format_wei_value(%Wei{} = wei, unit, options \\ []) when unit in @valid_units do
    converted_value =
      wei
      |> Wei.to(unit)

    formatted_value =
      if Decimal.cmp(converted_value, 1_000_000_000_000) == :gt do
        CldrHelper.Number.to_string!(converted_value, format: "0.###E+0")
      else
        CldrHelper.Number.to_string!(converted_value, format: "#,##0.##################")
      end

    if Keyword.get(options, :include_unit_label, true) do
      display_unit = display_unit(unit)
      "#{formatted_value} #{display_unit}"
    else
      formatted_value
    end
  end

  defp display_unit(:wei), do: gettext("Wei")
  defp display_unit(:gwei), do: gettext("Gwei")
  defp display_unit(:ether), do: gettext("Ether")
end
