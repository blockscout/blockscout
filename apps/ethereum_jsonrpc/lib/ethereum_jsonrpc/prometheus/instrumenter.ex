defmodule EthereumJSONRPC.Prometheus.Instrumenter do
  @moduledoc """
  JSON RPC metrics for `Prometheus`.
  """

  use Prometheus.Metric

  @counter [name: :json_rpc_requests_count, labels: [:method], help: "Number of JSON RPC requests"]
  @counter [name: :json_rpc_requests_errors_count, labels: [:method], help: "Number of JSON RPC requests errors"]

  @doc """
  Increments the JSON-RPC requests counter for a given method.

  ## Parameters

    - `method` (String): The name of the JSON-RPC method.
    - `req_count` (integer, optional): The number of requests to increment by. Defaults to 1.
  """
  @spec json_rpc_requests(String.t(), non_neg_integer()) :: :ok
  def json_rpc_requests(method, req_count \\ 1) do
    Counter.inc([name: :json_rpc_requests_count, labels: [method]], req_count)
  end

  @doc """
  Increments the counter for JSON-RPC errors for a given method.

  ## Parameters

    - `method` (string): The name of the JSON-RPC method that encountered an error.
    - `error_count` (integer, optional): The number of errors to increment the counter by. Defaults to 1.
  """
  @spec json_rpc_errors(String.t(), non_neg_integer()) :: :ok
  def json_rpc_errors(method, error_count \\ 1) do
    Counter.inc([name: :json_rpc_requests_errors_count, labels: [method]], error_count)
  end
end
