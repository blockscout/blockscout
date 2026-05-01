# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.HTTP.Helper do
  @moduledoc """
  Helper functions for `EthereumJSONRPC.HTTP` implementations.
  """

  @doc """
  Extracts the JSON-RPC method from a JSON string payload.

  Supports both single objects and batch requests (arrays).

  ## Parameters
  - `json_string`: The JSON string to parse

  ## Returns
  - The method name as a binary, or `{:error, Jason.DecodeError.t()}` if extraction fails
  """
  @spec get_method_from_json_string(binary()) :: binary() | {:error, Jason.DecodeError.t()}
  def get_method_from_json_string(json_string) do
    with {:ok, decoded_json} <- Utils.JSON.decode(json_string) do
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

  @doc """
  Conditionally decompresses gzip-encoded HTTP response bodies.

  Checks application configuration and HTTP headers to determine if decompression
  should be attempted.

  ## Parameters
  - `body`: The response body to potentially decompress
  - `headers`: List of HTTP response headers as {key, value} tuples

  ## Returns
  - Decompressed body if gzip-enabled and content is gzipped, otherwise original body
  """
  @spec try_unzip(binary(), [{binary(), binary()}]) :: binary()
  def try_unzip(body, headers) do
    request_compression_all_methods_enabled? =
      Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.HTTP)[:request_compression_all_methods_enabled?]

    if request_compression_all_methods_enabled? do
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

  @doc """
  Determines whether HTTP request compression should be enabled for a given JSON-RPC method.

  Compression is enabled when either the all-methods flag is true, or when the
  heavy-methods flag is true and the method is classified as heavy. Heavy methods
  include trace_*, debug_*, and eth_getBlockReceipts.

  ## Parameters
  - `method`: The JSON-RPC method name (binary) or term
  - `config`: Optional keyword list of configuration options (defaults to application environment)

  ## Returns
  - `true` if request compression should be enabled, `false` otherwise
  """
  @spec request_compression_enabled?(binary() | term(), keyword() | nil) :: boolean()
  def request_compression_enabled?(method, config \\ Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.HTTP, [])) do
    request_compression_all_methods_enabled? =
      Keyword.get(config, :request_compression_all_methods_enabled?, false)

    request_compression_heavy_methods_enabled? =
      Keyword.get(config, :request_compression_heavy_methods_enabled?, true)

    request_compression_all_methods_enabled? ||
      (request_compression_heavy_methods_enabled? && heavy_request_method?(method))
  end

  @doc """
  Determines whether a JSON-RPC method is classified as a "heavy" request.

  Heavy methods are those with high payload or computational requirements,
  specifically methods starting with trace_ or debug_ prefixes, or the
  eth_getBlockReceipts method.

  ## Parameters
  - `method`: The JSON-RPC method name (binary) or any term

  ## Returns
  - `true` if the method is classified as heavy, `false` otherwise
  """
  @spec heavy_request_method?(binary() | term()) :: boolean()
  def heavy_request_method?(method) when is_binary(method) do
    String.starts_with?(method, ["trace_", "debug_"]) || method == "eth_getBlockReceipts"
  end

  def heavy_request_method?(_method), do: false
end
