defmodule Explorer.HttpClient.Tesla do
  @moduledoc false

  def get(url, headers, options) do
    options
    |> client()
    |> Tesla.get(url, headers: headers, opts: request_opts(options))
    |> parse_response()
  end

  def get!(url, headers, options) do
    options
    |> client()
    |> Tesla.get!(url, headers: headers, opts: request_opts(options))
    |> parse_response()
  end

  def post(url, body, headers, options) do
    options
    |> client()
    |> Tesla.post(url, body, headers: headers, opts: request_opts(options))
    |> parse_response()
  end

  def head(url, headers, options) do
    options
    |> client()
    |> Tesla.head(url, headers: headers, opts: request_opts(options))
    |> parse_response()
  end

  defp parse_response({:ok, %{body: body, status: status_code, headers: response_headers}}) do
    {:ok, %{body: body, status_code: status_code, headers: response_headers}}
  end

  defp parse_response(%{body: body, status: status_code, headers: response_headers}) do
    %{body: body, status_code: status_code, headers: response_headers}
  end

  defp parse_response(error), do: error

  defp client(options) do
    options[:recv_timeout]
    |> add_timeout_middleware()
    |> add_follow_redirect_middleware(options[:follow_redirect])
    |> Tesla.client()
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

  defp request_opts(options) do
    adapter_options =
      [protocols: [:http1]]
      |> add_recv_timeout_option(options[:recv_timeout])
      |> add_timeout_option(options[:timeout])

    [adapter: adapter_options]
  end

  defp add_recv_timeout_option(options, nil), do: options

  defp add_recv_timeout_option(options, timeout) do
    Keyword.put(options, :timeout, timeout)
  end

  defp add_timeout_option(options, nil), do: options

  defp add_timeout_option(options, timeout) do
    Keyword.put(options, :transport_opts, timeout: timeout)
  end
end
