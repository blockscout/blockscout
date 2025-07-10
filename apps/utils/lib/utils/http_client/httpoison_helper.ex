defmodule Utils.HttpClient.HTTPoisonHelper do
  @moduledoc """
  Helper module for building HTTPoison request options.

  This module provides utilities to construct keyword lists of options
  for HTTPoison HTTP client requests, including timeouts, authentication,
  redirects, and connection pooling.
  """

  def request_opts(options) do
    []
    |> add_recv_timeout_option(options[:recv_timeout])
    |> add_timeout_option(options[:timeout])
    |> add_basic_auth_option(options[:basic_auth])
    |> add_pool_option(options[:pool])
    |> add_follow_redirect_option(options[:follow_redirect])
    |> add_insecure_option(options[:insecure])
    |> add_params_option(options[:params])
  end

  defp add_recv_timeout_option(options, nil), do: options

  defp add_recv_timeout_option(options, timeout) do
    Keyword.put(options, :recv_timeout, timeout)
  end

  defp add_params_option(options, nil), do: options

  defp add_params_option(options, params) do
    Keyword.put(options, :params, params)
  end

  defp add_timeout_option(options, nil), do: options

  defp add_timeout_option(options, timeout) do
    Keyword.put(options, :timeout, timeout)
  end

  defp add_follow_redirect_option(options, nil), do: options

  defp add_follow_redirect_option(options, follow_redirect) do
    Keyword.put(options, :follow_redirect, follow_redirect)
  end

  defp add_insecure_option(options, true) do
    Keyword.put(options, :hackney, [:insecure | options[:hackney] || []])
  end

  defp add_insecure_option(options, _insecure), do: options

  defp add_basic_auth_option(options, {username, password}) do
    Keyword.put(options, :hackney, [{:basic_auth, {username, password}} | options[:hackney] || []])
  end

  defp add_basic_auth_option(options, _basic_auth), do: options

  defp add_pool_option(options, nil), do: options

  defp add_pool_option(options, pool) do
    Keyword.put(options, :hackney, [{:pool, pool} | options[:hackney] || []])
  end
end
