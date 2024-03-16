defmodule EthereumJSONRPC.Block.ByHash do
  @moduledoc """
  Block format as returned by [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  """

  def request(%{id: id, hash: hash}, hydrated \\ true) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getBlockByHash", params: [hash, hydrated]})
  end
end
