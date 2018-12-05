defmodule EthereumJSONRPC.Block.ByNumber do
  @moduledoc """
  Block format as returned by [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  def request(%{id: id, number: number}) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getBlockByNumber", params: [integer_to_quantity(number), true]})
  end
end
