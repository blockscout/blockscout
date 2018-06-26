defmodule EthereumJSONRPC.Geth do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Geth](https://github.com/ethereum/go-ethereum/wiki/geth).
  """

  @behaviour EthereumJSONRPC.Variant

  @doc """
  Internal transaction fetching is not supported currently for Geth.

  To signal to the caller that fetching is not supported, `:ignore` is returned

      iex> EthereumJSONRPC.Geth.fetch_internal_transactions([
      ...>   "0x2ec382949ba0b22443aa4cb38267b1fb5e68e188109ac11f7a82f67571a0adf3"
      ...> ])
      :ignore

  """
  @impl EthereumJSONRPC.Variant
  def fetch_internal_transactions(transaction_params) when is_list(transaction_params),
    do: :ignore

  @doc """
  Pending transaction fetching is not supported currently for Geth.

  To signal to the caller that fetching is not supported, `:ignore` is returned

      iex> EthereumJSONRPC.Geth.fetch_pending_transactions()
      :ignore

  """
  @impl EthereumJSONRPC.Variant
  def fetch_pending_transactions, do: :ignore
end
