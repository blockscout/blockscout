# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.Prometheus.Instrumenter do
  @moduledoc """
  JSON RPC metrics for `Prometheus`.
  """

  use Prometheus.Metric

  @counter [name: :json_rpc_requests_count, labels: [:method], help: "Number of JSON RPC requests"]
  @counter [name: :json_rpc_requests_errors_count, labels: [:method], help: "Number of JSON RPC requests errors"]

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
    counter_name = if l1?, do: :l1_json_rpc_requests_errors_count, else: :json_rpc_requests_errors_count
    Counter.inc([name: counter_name, labels: [method]], error_count)
  end
end
