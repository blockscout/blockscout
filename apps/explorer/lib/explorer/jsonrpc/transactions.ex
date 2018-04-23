defmodule Explorer.JSONRPC.Transactions do
  @moduledoc """
  List of transactions format as included in return from
  [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash) and
  [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbynumber).
  """

  alias Explorer.JSONRPC.Transaction

  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Transaction.elixir_to_params/1)
  end

  def params_to_hashes(params) when is_list(params) do
    Enum.map(params, &Transaction.params_to_hash/1)
  end

  def to_elixir(transactions) when is_list(transactions) do
    Enum.map(transactions, &Transaction.to_elixir/1)
  end
end
