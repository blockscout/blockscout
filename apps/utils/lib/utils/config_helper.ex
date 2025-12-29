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

  @doc """
  Safely gets environment variable, returning default value if the variable is not set or is an
  empty string.
  """
  @spec safe_get_env(String.t(), any()) :: String.t()
  def safe_get_env(env_var, default_value) do
    env_var
    |> System.get_env(default_value)
    |> case do
      "" -> default_value
      value -> value
    end
    |> to_string()
  end

  @doc """
  Safely gets URL - type environment variable.
  """
  @spec parse_url_env_var(String.t(), String.t() | nil, boolean()) :: String.t() | nil
  def parse_url_env_var(env_var, default_value \\ nil, trailing_slash_needed? \\ false) do
    with url when not is_nil(url) <- safe_get_env(env_var, default_value),
         url <- String.trim_trailing(url, "/"),
         true <- url != "",
         {url, true} <- {url, trailing_slash_needed?} do
      url <> "/"
    else
      {url, false} ->
        url

      false ->
        default_value
    end
  end
end
