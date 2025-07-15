defmodule Explorer.HttpClient.Tesla do
  @moduledoc false

  alias Utils.HttpClient.TeslaHelper

  def get(url, headers, options) do
    options
    |> TeslaHelper.client()
    |> Tesla.get(url, headers: headers, query: options[:params] || [], opts: TeslaHelper.request_opts(options))
    |> parse_response()
  end

  def get!(url, headers, options) do
    options
    |> TeslaHelper.client()
    |> Tesla.get!(url, headers: headers, query: options[:params] || [], opts: TeslaHelper.request_opts(options))
    |> parse_response()
  end

  def post(url, body, headers, options) do
    options
    |> TeslaHelper.client()
    |> Tesla.post(url, body, headers: headers, opts: TeslaHelper.request_opts(options))
    |> parse_response()
  end

  def head(url, headers, options) do
    options
    |> TeslaHelper.client()
    |> Tesla.head(url, headers: headers, opts: TeslaHelper.request_opts(options))
    |> parse_response()
  end

  def request(method, url, headers, body, options) do
    options
    |> TeslaHelper.client()
    |> Tesla.request(method: method, url: url, headers: headers, body: body, opts: TeslaHelper.request_opts(options))
    |> parse_response()
  end

  defp parse_response({:ok, %{body: body, status: status_code, headers: response_headers}}) do
    {:ok, %{body: body, status_code: status_code, headers: response_headers}}
  end

  defp parse_response(%{body: body, status: status_code, headers: response_headers}) do
    %{body: body, status_code: status_code, headers: response_headers}
  end

  defp parse_response(error), do: error
end
