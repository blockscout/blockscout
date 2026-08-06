# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.Prometheus.Instrumenter do
  @moduledoc """
  JSON RPC metrics for `Prometheus`.
  """

  use Prometheus.Metric

  @counter [
    name: :json_rpc_requests_count,
    labels: [:method],
    help: "Number of JSON RPC requests"
  ]
  @counter [
    name: :json_rpc_requests_errors_count,
    labels: [:method],
    help: "Number of JSON RPC requests errors"
  ]

  @counter [
    name: :l1_json_rpc_requests_count,
    labels: [:method],
    help: "Number of JSON RPC requests to the L1 node made by rollup modules"
  ]
  @counter [
    name: :l1_json_rpc_requests_errors_count,
    labels: [:method],
    help: "Number of JSON RPC requests errors to the L1 node made by rollup modules"
  ]

  @counter [
    name: :json_rpc_calls_count,
    labels: [:method],
    help: "Number of JSON RPC calls (each request within a batch is counted separately)"
  ]
  @counter [
    name: :l1_json_rpc_calls_count,
    labels: [:method],
    help:
      "Number of JSON RPC calls to the L1 node made by rollup modules (each request within a batch is counted separately)"
  ]

  @counter [
    name: :eth_call_requests_count,
    labels: [:method_id],
    help: "Number of `eth_call` JSON RPC requests grouped by the called method id (first 4 bytes of the `data`)"
  ]
  @counter [
    name: :l1_eth_call_requests_count,
    labels: [:method_id],
    help:
      "Number of `eth_call` JSON RPC requests to the L1 node made by rollup modules, grouped by the called method id (first 4 bytes of the `data`)"
  ]

  @doc """
  Increments the JSON-RPC requests counter for a given method.

  Requests to the L1 node made by rollup modules are counted separately via the
  `l1_json_rpc_requests_count` metric when `l1?` is `true`.

  ## Parameters

    - `method` (String): The name of the JSON-RPC method.
    - `l1?` (boolean, optional): Whether the request targets the L1 node. Defaults to `false`.
    - `req_count` (integer, optional): The number of requests to increment by. Defaults to 1.
  """
  @spec json_rpc_requests(String.t(), boolean(), non_neg_integer()) :: :ok
  def json_rpc_requests(method, l1? \\ false, req_count \\ 1) do
    counter_name = if l1?, do: :l1_json_rpc_requests_count, else: :json_rpc_requests_count
    Counter.inc([name: counter_name, labels: [method]], req_count)
  end

  @doc """
  Increments the counter for JSON-RPC errors for a given method.

  Errors of requests to the L1 node made by rollup modules are counted separately
  via the `l1_json_rpc_requests_errors_count` metric when `l1?` is `true`.

  ## Parameters

    - `method` (string): The name of the JSON-RPC method that encountered an error.
    - `l1?` (boolean, optional): Whether the request targets the L1 node. Defaults to `false`.
    - `error_count` (integer, optional): The number of errors to increment the counter by. Defaults to 1.
  """
  @spec json_rpc_errors(String.t(), boolean(), non_neg_integer()) :: :ok
  def json_rpc_errors(method, l1? \\ false, error_count \\ 1) do
    counter_name =
      if l1?, do: :l1_json_rpc_requests_errors_count, else: :json_rpc_requests_errors_count

    Counter.inc([name: counter_name, labels: [method]], error_count)
  end

  @doc """
  Increments the JSON-RPC calls counter for a given method by `call_count`.

  Unlike `json_rpc_requests/3`, which counts one increment per HTTP request
  (labeled by the first method of a batch), this counts each individual request
  within a batch, grouped by its method. This gives the exact number of requests
  per method.

  Calls to the L1 node made by rollup modules are counted separately via the
  `l1_json_rpc_calls_count` metric when `l1?` is `true`.

  ## Parameters

    - `method` (String): The name of the JSON-RPC method.
    - `l1?` (boolean, optional): Whether the request targets the L1 node. Defaults to `false`.
    - `call_count` (integer, optional): The number of calls to increment by. Defaults to 1.
  """
  @spec json_rpc_calls(String.t(), boolean(), non_neg_integer()) :: :ok
  def json_rpc_calls(method, l1? \\ false, call_count \\ 1) do
    counter_name = if l1?, do: :l1_json_rpc_calls_count, else: :json_rpc_calls_count
    Counter.inc([name: counter_name, labels: [method]], call_count)
  end

  @doc """
  Increments the `eth_call` requests counter for a given method id.

  The method id is the first 4 bytes of the `data` field of an `eth_call`
  request (e.g. `"0x70a08231"` for `balanceOf(address)`). This allows tracking
  how many `eth_call` requests are made for each specific contract method.

  Requests to the L1 node made by rollup modules are counted separately via the
  `l1_eth_call_requests_count` metric when `l1?` is `true`.

  ## Parameters

    - `method_id` (String): The 4-byte method id (hex string with `0x` prefix).
    - `l1?` (boolean, optional): Whether the request targets the L1 node. Defaults to `false`.
    - `req_count` (integer, optional): The number of requests to increment by. Defaults to 1.
  """
  @spec eth_call_requests(String.t(), boolean(), non_neg_integer()) :: :ok
  def eth_call_requests(method_id, l1? \\ false, req_count \\ 1) do
    counter_name = if l1?, do: :l1_eth_call_requests_count, else: :eth_call_requests_count
    Counter.inc([name: counter_name, labels: [method_id]], req_count)
  end
end
