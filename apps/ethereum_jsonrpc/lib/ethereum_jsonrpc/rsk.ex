defmodule EthereumJSONRPC.RSK do
  @moduledoc """
  Ethereum JSONRPC methods that are/are not supported by [RSK](https://www.rsk.co/).
  """

  alias EthereumJSONRPC.RSK.Traces
  alias EthereumJSONRPC.TraceBlock

  @behaviour EthereumJSONRPC.Variant

  def fetch_internal_transactions(_transaction_params, _json_rpc_named_arguments), do: :ignore

  def fetch_pending_transactions(_), do: :ignore

  def fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments) do
    TraceBlock.fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments, Traces)
  end

  def fetch_beneficiaries(_, _), do: :ignore
  def fetch_first_trace(_transactions_params, _json_rpc_named_arguments), do: :ignore
end
