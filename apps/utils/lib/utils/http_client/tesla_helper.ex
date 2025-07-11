defmodule Utils.HttpClient.TeslaHelper do
  @moduledoc """
  Helper module for building Tesla HTTP clients and adapter options.

  This module provides utilities to construct Tesla clients with appropriate
  middleware and adapter options, including timeouts, authentication, redirects,
  and TLS settings.
  """

  @doc """
  Builds a Tesla client with configured middleware based on the provided options.

  ## Parameters
  - `options`: A keyword list or map containing HTTP client options

  ## Returns
  - A Tesla client struct with configured middleware
  """
  @spec client(keyword() | map()) :: Tesla.Client.t()
  def client(options) do
    options[:recv_timeout]
    |> add_timeout_middleware()
    |> add_follow_redirect_middleware(options[:follow_redirect])
    |> add_basic_auth_middleware(options[:basic_auth])
    |> Tesla.client()
  end

  @doc """
  Builds adapter options for Tesla HTTP client requests from the provided options map.

  ## Parameters
  - `options`: A keyword list or map containing HTTP client options

  ## Returns
  - A keyword list containing adapter options for Tesla
  """
  @spec request_opts(keyword() | map()) :: keyword()
  def request_opts(options) do
    adapter_options =
      [protocols: [:http1]]
      |> add_recv_timeout_option(options[:recv_timeout])
      |> add_timeout_option(options[:timeout])
      |> add_insecure_option(options[:insecure])

    [adapter: adapter_options]
  end

  defp add_timeout_middleware(middleware \\ [], timeout)

  defp add_timeout_middleware(middleware, nil), do: middleware

  defp add_timeout_middleware(middleware, timeout) do
    [{Tesla.Middleware.Timeout, timeout: timeout} | middleware]
  end

  defp add_follow_redirect_middleware(middleware, true) do
    [Tesla.Middleware.FollowRedirects | middleware]
  end

  defp add_follow_redirect_middleware(middleware, _follow_redirect?), do: middleware

  defp add_basic_auth_middleware(middleware, {username, password}) do
    [{Tesla.Middleware.BasicAuth, %{username: username, password: password}} | middleware]
  end

  defp add_basic_auth_middleware(middleware, _basic_auth), do: middleware

  defp add_recv_timeout_option(options, nil), do: options

  defp add_recv_timeout_option(options, timeout) do
    Keyword.put(options, :timeout, timeout)
  end

  defp add_timeout_option(options, nil), do: options

  defp add_timeout_option(options, timeout) do
    Keyword.put(options, :transport_opts, [{:timeout, timeout} | options[:transport_opts] || []])
  end

  defp add_insecure_option(options, true) do
    Keyword.put(options, :transport_opts, [{:verify, :verify_none} | options[:transport_opts] || []])
  end

  defp add_insecure_option(options, _insecure), do: options
end
