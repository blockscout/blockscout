# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.HTTP.Helper do
  @moduledoc """
  Helper functions for `EthereumJSONRPC.HTTP` implementations.
  """

  require Logger

  alias EthereumJSONRPC.Prometheus.Instrumenter

  @doc """
  Tracks which contract methods are called via `eth_call` JSON-RPC requests.

  For every `eth_call` in the payload (both single requests and batches) the
  method id (first 4 bytes of the `data` field, e.g. `"0x70a08231"`) is
  extracted, logged at the `debug` level and reported to the
  `eth_call_requests_count` Prometheus metric. Requests to the L1 node made by
  rollup modules (`l1?` is `true`) are reported to the separate
  `l1_eth_call_requests_count` metric instead.

  Only runs its work when `method` is `"eth_call"`, so the extra JSON decoding
  cost is avoided for all other requests.

  ## Parameters
  - `json_string`: The raw JSON string payload sent to the node
  - `method`: The JSON-RPC method already extracted from the payload
  - `l1?`: Whether the request targets the L1 node. Defaults to `false`.

  ## Returns
  - `:ok`
  """
  @spec track_eth_call_methods(binary(), binary() | {:error, Jason.DecodeError.t()} | nil, boolean()) :: :ok
  def track_eth_call_methods(json_string, method, l1? \\ false)

  def track_eth_call_methods(json_string, "eth_call", l1?) do
    json_string
    |> get_eth_call_method_ids_from_json_string()
    |> Enum.frequencies()
    |> Enum.each(fn {method_id, count} ->
      Logger.debug(fn ->
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        "eth_call request to method id #{method_id} on #{if l1?, do: "L1", else: "L2"} (count: #{count})"
      end)

      Instrumenter.eth_call_requests(method_id, l1?, count)
    end)
  end

  def track_eth_call_methods(_json_string, _method, _l1?), do: :ok

  @doc """
  Extracts the method ids (first 4 bytes of the `data` field) of all `eth_call`
  requests contained in a JSON string payload.

  Supports both single objects and batch requests (arrays). Non-`eth_call`
  requests and requests without a decodable `data` field are ignored.

  ## Parameters
  - `json_string`: The JSON string to parse

  ## Returns
  - A list of method id binaries (hex strings with `0x` prefix). Empty when the
    payload contains no `eth_call` request or cannot be decoded.
  """
  @spec get_eth_call_method_ids_from_json_string(binary()) :: [binary()]
  def get_eth_call_method_ids_from_json_string(json_string) do
    case Jason.decode(json_string) do
      {:ok, decoded_json} ->
        decoded_json
        |> List.wrap()
        |> Enum.map(&eth_call_method_id/1)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp eth_call_method_id(%{"method" => "eth_call", "params" => [%{} = call_params | _]}) do
    (call_params["data"] || call_params["input"]) |> method_id_from_data()
  end

  defp eth_call_method_id(_request), do: nil

  defp method_id_from_data("0x" <> _rest = data) when byte_size(data) >= 10, do: binary_part(data, 0, 10)
  defp method_id_from_data(_data), do: nil

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
