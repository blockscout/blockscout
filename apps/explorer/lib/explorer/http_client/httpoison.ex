defmodule Explorer.HttpClient.HTTPoison do
  @moduledoc false

  alias Utils.HttpClient.HTTPoisonHelper

  def get(url, headers, options) do
    url
    |> HTTPoison.get(headers, HTTPoisonHelper.request_opts(options))
    |> parse_response()
  end

  def get!(url, headers, options) do
    url
    |> HTTPoison.get!(headers, HTTPoisonHelper.request_opts(options))
    |> parse_response()
  end

  def post(url, body, headers, options) do
    url
    |> HTTPoison.post(body, headers, HTTPoisonHelper.request_opts(options))
    |> parse_response()
  end

  def head(url, headers, options) do
    url
    |> HTTPoison.head(headers, HTTPoisonHelper.request_opts(options))
    |> parse_response()
  end

  def request(method, url, headers, body, options) do
    method
    |> HTTPoison.request(url, body, headers, HTTPoisonHelper.request_opts(options))
    |> parse_response()
  end

  defp parse_response({:ok, %{body: body, status_code: status_code, headers: response_headers}}) do
    {:ok, %{body: body, status_code: status_code, headers: response_headers}}
  end

  defp parse_response(%{body: body, status_code: status_code, headers: response_headers}) do
    %{body: body, status_code: status_code, headers: response_headers}
  end

  defp parse_response({:error, %{reason: reason}}), do: {:error, reason}
  defp parse_response(error), do: error
end
