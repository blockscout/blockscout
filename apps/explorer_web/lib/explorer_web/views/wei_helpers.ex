defmodule ExplorerWeb.WeiHelpers do
  @moduledoc """
  Helper functions for interacting with `t:Explorer.Chain.Wei.t/0` values.
  """

  import ExplorerWeb.Gettext

  alias Explorer.Chain.Wei

  @valid_units ~w(wei gwei ether)a

  @type format_option :: {:fractional_digits, pos_integer()} | {:include_unit_label, boolean()}

  @type format_options :: [format_option()]

  @doc """
  Converts a `t:Explorer.Wei.t/0` value to the specified unit including a
  translated unit label.

  ## Supported Formatting Options

  The third argument allows for keyword options to be passed for formatting the
  converted number.

  * `:fractional_digits` - Integer. Number of fractional digits to include
  * `:include_unit_label` - Boolean (Defaults to `true`). Flag for if the unit
    label should be included in the returned string

  ## Examples

      iex> format_wei_value(%Wei{value: Decimal.new(1)}, :wei)
      "1 Wei"

      iex> format_wei_value(%Wei{value: Decimal.new(1, 10, 12)}, :gwei)
      "10,000 Gwei"

      iex> format_wei_value(%Wei{value: Decimal.new(1, 10, 21)}, :ether)
      "10,000 POA"

      # With formatting options

      iex> format_wei_value(
      ...>   %Wei{value: Decimal.new(1)},
      ...>   :wei,
      ...>   fractional_digits: 3
      ...> )
      "1.000 Wei"

      iex> format_wei_value(
      ...>   %Wei{value: Decimal.new(10)},
      ...>   :wei,
      ...>   include_unit_label: false
      ...> )
      "10"
  """
  @spec format_wei_value(Wei.t(), Wei.unit(), format_options()) :: String.t()
  def format_wei_value(%Wei{} = wei, unit, options \\ []) when unit in @valid_units do
    number_format_options = build_number_format_options(options)

    converted_value =
      wei
      |> Wei.to(unit)
      |> Cldr.Number.to_string!(number_format_options)

    if Keyword.get(options, :include_unit_label, true) do
      display_unit = display_unit(unit)
      "#{converted_value} #{display_unit}"
    else
      converted_value
    end
  end

  defp build_number_format_options(options) do
    Enum.reduce(options, [], fn option, formatted_options ->
      case parse_number_format_option(option) do
        nil -> formatted_options
        {key, value} -> Keyword.put(formatted_options, key, value)
      end
    end)
  end

  defp display_unit(:wei), do: gettext("Wei")
  defp display_unit(:gwei), do: gettext("Gwei")
  defp display_unit(:ether), do: gettext("Ether")

  defguardp is_fractional_digit(digits) when is_integer(digits) and digits > 0

  defp parse_number_format_option({:fractional_digits, digits}) when is_fractional_digit(digits) do
    {:fractional_digits, digits}
  end

  defp parse_number_format_option(_), do: nil
end
