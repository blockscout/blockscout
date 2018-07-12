defmodule EthereumJSONRPC.Geth do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Geth](https://github.com/ethereum/go-ethereum/wiki/geth).
  """

  @behaviour EthereumJSONRPC.Variant

  @doc """
  Internal transaction fetching is not supported currently for Geth.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_internal_transactions(transaction_params, _json_rpc_named_arguments) when is_list(transaction_params),
    do: :ignore

  @doc """
  Pending transaction fetching is not supported currently for Geth.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_pending_transactions(_json_rpc_named_arguments), do: :ignore
end
