defmodule EthereumJSONRPC.Block.ByNephew do
  @moduledoc """
  Block format as returned by [`eth_getUncleByBlockHashAndIndex`](https://github.com/ethereum/wiki/wiki/JSON-RPC/e8e0771b9f3677693649d945956bc60e886ceb2b#eth_getunclebyblockhashandindex)
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  def request(%{id: id, nephew_hash: nephew_hash, index: index}) do
    EthereumJSONRPC.request(%{
      id: id,
      method: "eth_getUncleByBlockHashAndIndex",
      params: [nephew_hash, integer_to_quantity(index)]
    })
  end
end
