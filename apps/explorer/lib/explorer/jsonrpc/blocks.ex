defmodule Explorer.JSONRPC.Blocks do
  @moduledoc """
  Blocks format as returned by [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  and [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbynumber) from batch requests.
  """

  alias Explorer.JSONRPC.{Block, Transactions}

  # Types

  @type elixir :: [Block.elixir()]
  @type t :: [Block.t()]

  # Functions

  @spec elixir_to_params(elixir) :: [map]
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Block.elixir_to_params/1)
  end

  @spec elixir_to_transactions(t) :: Transactions.elixir()
  def elixir_to_transactions(elixir) when is_list(elixir) do
    Enum.flat_map(elixir, &Block.elixir_to_transactions/1)
  end

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0` and the timestamps to `t:DateTime.t/0`
  """
  @spec to_elixir(t) :: elixir
  def to_elixir(blocks) when is_list(blocks) do
    Enum.map(blocks, &Block.to_elixir/1)
  end
end
