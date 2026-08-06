# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.HTTP.Helper do
  @moduledoc """
  Helper functions for `EthereumJSONRPC.HTTP` implementations.
  """

  require Logger

  alias EthereumJSONRPC.Prometheus.Instrumenter

  @doc """
  Decodes a raw JSON-RPC payload into a list of request maps.

  Both single requests (a JSON object) and batch requests (a JSON array) are
  normalized to a list, so callers can treat every payload uniformly. Returns an
  empty list when the payload cannot be decoded.

  ## Parameters
  - `json_string`: The raw JSON string payload sent to the node

  ## Returns
  - A list of decoded request maps, or `[]` when decoding fails.
  """
  @spec decode_requests(binary()) :: [map()]
  def decode_requests(json_string) do
    case Jason.decode(json_string) do
      {:ok, decoded} -> decoded |> List.wrap() |> Enum.filter(&is_map/1)
      _ -> []
    end
  end

  @doc """
  Reports the number of individual JSON-RPC calls, grouped by method, to the
  `json_rpc_calls_count` Prometheus metric.

  Unlike `json_rpc_requests_count`, which counts one increment per HTTP request
  (labeled by the first method of a batch), this counts each request within a
  batch, giving the exact number of requests per method. Calls to the L1 node
  made by rollup modules (`l1?` is `true`) are reported to the separate
  `l1_json_rpc_calls_count` metric instead.

  ## Parameters
  - `requests`: The decoded JSON-RPC requests (as returned by `decode_requests/1`)
  - `l1?`: Whether the request targets the L1 node. Defaults to `false`.

  ## Returns
  - `:ok`
  """
  @spec track_json_rpc_calls([map()], boolean()) :: :ok
  def track_json_rpc_calls(requests, l1? \\ false) do
    requests
    |> Enum.frequencies_by(&Map.get(&1, "method"))
    |> Enum.each(fn
      {nil, _count} -> :ok
      {method, count} -> Instrumenter.json_rpc_calls(method, l1?, count)
    end)
  end

  @doc """
  Tracks which contract methods are called via `eth_call` JSON-RPC requests.

  For every `eth_call` in the payload (both single requests and batches) the
  method id (first 4 bytes of the `data` field, e.g. `"0x70a08231"`) is
  extracted, logged at the `debug` level and reported to the
  `eth_call_requests_count` Prometheus metric. Requests to the L1 node made by
  rollup modules (`l1?` is `true`) are reported to the separate
  `l1_eth_call_requests_count` metric instead.

  ## Parameters
  - `requests`: The decoded JSON-RPC requests (as returned by `decode_requests/1`)
  - `l1?`: Whether the request targets the L1 node. Defaults to `false`.

  ## Returns
  - `:ok`
  """
  @spec track_eth_call_methods([map()], boolean()) :: :ok
  def track_eth_call_methods(requests, l1? \\ false) do
    requests
    |> Enum.map(&eth_call_method_id/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.each(fn {method_id, count} ->
      Logger.debug(fn ->
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        "eth_call request to method id #{method_id} on #{if l1?, do: "L1", else: "L2"} (count: #{count})"
      end)

      Instrumenter.eth_call_requests(method_id, l1?, count)
    end)
  end

  defp eth_call_method_id(%{"method" => "eth_call", "params" => [%{} = call_params | _]}) do
    (call_params["data"] || call_params["input"]) |> method_id_from_data()
  end

  defp eth_call_method_id(_request), do: nil

  @spec method_id_from_data(binary() | nil) :: binary() | nil
  defp method_id_from_data("0x" <> _rest = data) when byte_size(data) >= 10,
    do: binary_part(data, 0, 10)

  defp method_id_from_data(_data), do: nil

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
