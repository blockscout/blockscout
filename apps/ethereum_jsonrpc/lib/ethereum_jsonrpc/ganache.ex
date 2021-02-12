defmodule EthereumJSONRPC.Ganache do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Ganache](https://github.com/trufflesuite/ganache-core#implemented-methods).
  """

  @behaviour EthereumJSONRPC.Variant

  @doc """
  Block reward contract beneficiary fetching is not supported currently for Ganache.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_beneficiaries(_block_range, _json_rpc_named_arguments), do: :ignore

  @doc """
  Internal transaction fetching is not currently supported for Ganache.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_internal_transactions(_transactions_params, _json_rpc_named_arguments), do: :ignore

  @doc """
  Internal transaction fetching is not currently supported for Ganache.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_block_internal_transactions(_block_range, _json_rpc_named_arguments), do: :ignore

  @doc """
  Pending transaction fetching is not supported currently for Ganache.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_pending_transactions(_json_rpc_named_arguments), do: :ignore

  @doc """
  Traces are not supported currently for Ganache.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_first_trace(_transactions_params, _json_rpc_named_arguments), do: :ignore
end
