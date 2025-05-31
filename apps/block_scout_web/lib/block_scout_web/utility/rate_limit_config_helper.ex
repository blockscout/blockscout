defmodule BlockScoutWeb.Utility.RateLimitConfigHelper do
  @moduledoc """
  Fetches the rate limit config from the config url and parses it into a map.
  """
  require Logger

  alias Utils.ConfigHelper

  @doc """
  Fetches the rate limit config from the config url and puts it into the persistent term under the key `:rate_limit_config`.
  """
  @spec fetch_config() :: :ok
  def fetch_config do
    :persistent_term.put(:rate_limit_config, fetch_config_inner())
  end

  defp fetch_config_inner do
    url = Application.get_env(:block_scout_web, :api_rate_limit)[:config_url]

    with {:ok, config} <- download_config(url),
         parsed_config <- parse_config(config) do
      parsed_config
    else
      {:error, reason} ->
        Logger.error("Failed to fetch rate limit config: #{inspect(reason)}. Fallback to local config.")
        fallback_config()
    end
  rescue
    error ->
      Logger.error("Failed to fetch config: #{inspect(error)}. Fallback to local config.")
      fallback_config()
  end

  defp fallback_config do
    with {:ok, config} <-
           :block_scout_web
           |> Application.app_dir("priv/rate_limit_config.json")
           |> File.read(),
         {:ok, config} <- decode_config(config),
         config <- parse_config(config) do
      config
    else
      {:error, reason} ->
        Logger.error("Failed to parse local config: #{inspect(reason)}. Using default rate limits from ENVs.")
        %{}
    end
  end

  defp download_config(url) when is_binary(url) do
    url
    |> HTTPoison.get([], follow_redirect: true)
    |> case do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        decode_config(body)

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.error("Failed to fetch config from #{url}: #{status}")
        {:error, status}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp download_config(_), do: {:error, :invalid_config_url}

  defp decode_config(config) do
    to_atom? =
      Map.from_keys(
        [
          "account_api_key",
          "bypass_token_scope",
          "cost",
          "ip",
          "ignore",
          "limit",
          "period",
          "recaptcha_to_bypass_429",
          "static_api_key",
          "temporary_token",
          "whitelisted_ip"
        ],
        true
      )

    config
    |> Jason.decode(
      keys: fn key ->
        if to_atom?[key] do
          String.to_atom(key)
        else
          key
        end
      end
    )
  end

  defp parse_config(config) do
    config = decode_time_values(config)

    config
    |> Map.keys()
    |> Enum.reduce(%{wildcard_match: %{}, parametrized_match: %{}, static_match: %{}}, fn key, acc ->
      {type, value} = process_endpoint_path(key)

      Map.update(acc, type, %{value => config[key]}, fn existing_value ->
        Map.put(existing_value, value, config[key])
      end)
    end)
  end

  defp process_endpoint_path(key) do
    path_parts = key |> String.trim("/") |> String.split("/")

    cond do
      String.contains?(key, "*") ->
        if Enum.find_index(path_parts, &Kernel.==(&1, "*")) == length(path_parts) - 1 do
          {:wildcard_match, {Enum.drop(path_parts, -1), length(path_parts) - 1}}
        else
          raise "wildcard `*` allowed only at the end of the path"
        end

      String.contains?(key, ":param") ->
        {:parametrized_match, path_parts}

      true ->
        {:static_match, key}
    end
  end

  defp decode_time_values(config) when is_map(config) do
    config
    |> Enum.map(fn
      {:period, value} when is_binary(value) ->
        {:period, parse_time_string(value)}

      {key, value} when is_map(value) ->
        {key, decode_time_values(value)}

      entry ->
        entry
    end)
    |> Enum.into(%{})
  end

  defp parse_time_string(value) do
    case ConfigHelper.parse_time_value(value) do
      :error ->
        raise "Invalid time format in rate limit config: #{value}"

      time ->
        time
    end
  end
end
