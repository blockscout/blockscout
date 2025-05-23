defmodule Utils.ConfigHelper do
  @moduledoc """
  Helper functions for parsing config values.
  """

  @doc """
  Parses a time value from a string.
  """
  @spec parse_time_value(String.t()) :: non_neg_integer() | :error
  def parse_time_value(value) do
    case value |> String.downcase() |> Integer.parse() do
      {milliseconds, "ms"} -> milliseconds
      {hours, "h"} -> :timer.hours(hours)
      {minutes, "m"} -> :timer.minutes(minutes)
      {seconds, s} when s in ["s", ""] -> :timer.seconds(seconds)
      _ -> :error
    end
  end
end
