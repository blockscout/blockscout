defmodule EthereumJSONRPC.HTTP.HTTPoison do
  @moduledoc """
  Uses `HTTPoison` for `EthereumJSONRPC.HTTP`
  """

  alias EthereumJSONRPC.HTTP

  @behaviour HTTP

  @impl HTTP
  def json_rpc(url, json, headers, options) when is_binary(url) and is_list(options) do
    gzip_enabled? = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.HTTP)[:gzip_enabled?]

    headers =
      if gzip_enabled? do
        [{"Accept-Encoding", "gzip"} | headers]
      else
        headers
      end

    case HTTPoison.post(url, json, headers, options) do
      {:ok, %HTTPoison.Response{body: body, status_code: status_code, headers: headers}} ->
        {:ok, %{body: try_unzip(gzip_enabled?, body, headers), status_code: status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def json_rpc(url, _json, _headers, _options) when is_nil(url), do: {:error, "URL is nil"}

  defp try_unzip(true, body, headers) do
    gzipped =
      Enum.any?(
        headers
        |> Enum.map(fn {k, v} ->
          {String.downcase(k), String.downcase(v)}
        end),
        fn kv ->
          case kv do
            {"content-encoding", "gzip"} -> true
            {"content-encoding", "x-gzip"} -> true
            _ -> false
          end
        end
      )

    if gzipped do
      :zlib.gunzip(body)
    else
      body
    end
  end

  defp try_unzip(_gzip_enabled?, body, _headers) do
    body
  end
end
