defmodule Explorer.HttpClient.HTTPoison do
  @moduledoc false

  def get(url, headers, options) do
    url
    |> HTTPoison.get(headers, options)
    |> parse_response()
  end

  def get!(url, headers, options) do
    url
    |> HTTPoison.get!(headers, options)
    |> parse_response()
  end

  def post(url, body, headers, options) do
    url
    |> HTTPoison.post(body, headers, options)
    |> parse_response()
  end

  def head(url, headers, options) do
    url
    |> HTTPoison.head(headers, options)
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
