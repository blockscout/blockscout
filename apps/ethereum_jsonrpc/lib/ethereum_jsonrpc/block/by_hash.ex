defmodule EthereumJSONRPC.Block.ByHash do
  @moduledoc """
  Block format as returned by [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  """

  @include_transactions true

  def request(%{id: id, hash: hash}) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getBlockByHash", params: [hash, @include_transactions]})
  end
end
