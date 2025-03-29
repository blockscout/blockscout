defmodule EthereumJSONRPC.HTTP.HTTPoison do
  @moduledoc """
  Uses `HTTPoison` for `EthereumJSONRPC.HTTP`
  """

  alias EthereumJSONRPC.HTTP
  alias EthereumJSONRPC.Prometheus.Instrumenter

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

    method = get_method_from_json_string(json)

    Instrumenter.json_rpc_requests(method)

    case HTTPoison.post(url, json, headers, options) do
      {:ok, %HTTPoison.Response{body: body, status_code: status_code, headers: headers}} ->
        with {:ok, decoded_body} <- Jason.decode(body),
             true <- response_body_has_error?(decoded_body) do
          Instrumenter.json_rpc_errors(method)
        end

        {:ok, %{body: try_unzip(gzip_enabled?, body, headers), status_code: status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Instrumenter.json_rpc_errors(method)

        {:error, reason}
    end
  end

  def json_rpc(url, _json, _headers, _options) when is_nil(url), do: {:error, "URL is nil"}

  defp get_method_from_json_string(json_string) do
    with {:ok, decoded_json} <- Jason.decode(json_string) do
      if is_map(decoded_json) do
        Map.get(decoded_json, "method")
      else
        decoded_json |> Enum.at(0) |> Map.get("method")
      end
    end
  end

  defp response_body_has_error?(decoded_body) when is_map(decoded_body) do
    Map.has_key?(decoded_body, "error")
  end

  defp response_body_has_error?(decoded_body) when is_list(decoded_body) do
    Enum.any?(decoded_body, &response_body_has_error?/1)
  end

  defp response_body_has_error?(_decoded_body), do: false

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
