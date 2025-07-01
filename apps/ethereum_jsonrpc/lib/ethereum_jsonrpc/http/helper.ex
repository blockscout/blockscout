defmodule EthereumJSONRPC.HTTP.Helper do
  @moduledoc """
  Helper functions for `EthereumJSONRPC.HTTP` implementations.
  """

  @spec get_method_from_json_string(binary()) :: binary()
  def get_method_from_json_string(json_string) do
    with {:ok, decoded_json} <- Jason.decode(json_string) do
      if is_map(decoded_json) do
        Map.get(decoded_json, "method")
      else
        decoded_json |> Enum.at(0) |> Map.get("method")
      end
    end
  end

  @spec response_body_has_error?(map() | [map()]) :: boolean()
  def response_body_has_error?(decoded_body) when is_map(decoded_body) do
    Map.has_key?(decoded_body, "error")
  end

  def response_body_has_error?(decoded_body) when is_list(decoded_body) do
    Enum.any?(decoded_body, &response_body_has_error?/1)
  end

  def response_body_has_error?(_decoded_body), do: false

  @spec try_unzip(binary(), [{binary(), binary()}]) :: binary()
  def try_unzip(body, headers) do
    gzip_enabled? = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.HTTP)[:gzip_enabled?]

    if gzip_enabled? do
      do_unzip(body, headers)
    else
      body
    end
  end

  defp do_unzip(body, headers) do
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
end
