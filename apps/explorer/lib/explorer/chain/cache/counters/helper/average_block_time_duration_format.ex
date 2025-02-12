defmodule Explorer.Chain.Cache.Counters.Helper.AverageBlockTimeDurationFormat do
  @moduledoc """
  A `Timex.Format.Duration.Formatter` that renders the most significant unit out to one decimal point.
  """

  use Timex.Format.Duration.Formatter
  alias Timex.Translator

  @millisecond 1
  @second @millisecond * 1000
  @minute @second * 60
  @hour @minute * 60
  @day @hour * 24
  @week @day * 7
  @month @day * 30
  @year @day * 365

  @unit_term_mapping [
    {@year, "year"},
    {@month, "month"},
    {@week, "week"},
    {@day, "day"},
    {@hour, "hour"},
    {@minute, "minute"},
    {@second, "second"},
    {@millisecond, "millisecond"}
  ]

  @doc """
  Formats a duration as a single value and a decimal part.

  See `lformat/2` for more information.

      iex> use Timex
      ...> Duration.from_erl({0, 65, 0}) |> #{__MODULE__}.format()
      "1.1 minutes"
  """
  @spec format(Duration.t()) :: String.t() | {:error, term}
  def format(%Duration{} = duration), do: lformat(duration, Translator.current_locale())
  def format(_), do: {:error, :invalid_duration}

  @doc """
  Formats a duration as a single value and a decimal part.

  Chooses the greatest whole unit available from:

  * year
  * month
  * week
  * day
  * hour
  * minute
  * second
  * millisecond

  Accepts a translation locale and honors it for the units.

      iex> use Timex
      ...> Duration.from_erl({0, 65, 0}) |> #{__MODULE__}.lformat("en")
      "1.1 minutes"

      iex> use Timex
      ...> Duration.from_erl({0, 0, 0}) |> #{__MODULE__}.lformat("en")
      "0 milliseconds"
  """
  def lformat(%Duration{} = duration, locale) do
    duration
    |> Duration.to_milliseconds()
    |> round()
    |> abs()
    |> do_format(locale)
  end

  def lformat(_, _locale), do: {:error, :invalid_duration}

  defp do_format(0, locale) do
    Translator.translate_plural(locale, "units", "%{count}, millisecond", "%{count} milliseconds", 0)
  end

  for {unit, name} <- @unit_term_mapping do
    defp do_format(value, locale) when value >= unquote(unit) do
      format_unit(locale, unquote(unit), value, unquote(name))
    end
  end

  defp format_unit(locale, unit, value, singular) do
    decimal_value = value / unit
    truncated = trunc(decimal_value)

    # remove any trailing `.0`
    if decimal_value == truncated do
      Translator.translate_plural(locale, "units", "%{count} #{singular}", "%{count} #{singular}s", truncated)
    else
      value =
        decimal_value
        |> Float.round(1)
        |> :erlang.float_to_binary(decimals: 1)

      locale
      |> Translator.translate_plural("units", "%{count} #{singular}", "%{count} #{singular}s", 5)
      |> String.replace("5", value)
    end
  end
end
