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
      {days, "d"} -> :timer.hours(24) * days
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
    |> then(fn
      nil -> ""
      value -> to_string(value)
    end)
  end

  @doc """
  Parses an URL from an environment variable with optional trailing slash handling.

  Retrieves the URL from the specified environment variable, normalizes it by
  trimming any trailing slash, and optionally appends a trailing slash based
  on the `trailing_slash_needed?` parameter. If the environment variable is
  not set or is empty, returns the default value or nil.

  ## Parameters
  - `env_var`: The name of the environment variable containing the URL.
  - `default_value`: The value to return if the environment variable is not
    set or is empty (default: nil).
  - `trailing_slash_needed?`: Whether to append a trailing slash to non-empty
    URLs (default: false).

  ## Returns
  - A normalized URL string (with or without trailing slash based on the
    `trailing_slash_needed?` parameter) if the environment variable contains
    a non-empty value.
  - The `default_value` if the environment variable is not set or is empty.
  - nil if the environment variable is not set and no default value is
    provided.
  """
  @spec parse_url_env_var(String.t(), String.t() | nil, boolean()) :: String.t() | nil
  def parse_url_env_var(env_var, default_value \\ nil, trailing_slash_needed? \\ false) do
    with url when url != "" <- safe_get_env(env_var, default_value),
         true <- valid_url?(url),
         url <- String.trim_trailing(url, "/"),
         {url, true} <- {url, trailing_slash_needed?} do
      url <> "/"
    else
      {url, false} ->
        url

      _ ->
        default_value
    end
  end

  @doc """
  Checks if input string is a valid URL
  """
  @spec valid_url?(term()) :: boolean()
  def valid_url?(string) when is_binary(string) do
    uri = URI.parse(string)

    !is_nil(uri.scheme) && !is_nil(uri.host)
  end

  def valid_url?(_), do: false
end
