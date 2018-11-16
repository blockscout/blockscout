defmodule EthereumJSONRPC.Blocks.ByHash do
  @moduledoc """
  Blocks format as returned by [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  from batch requests.
  """

  alias EthereumJSONRPC.Block

  def requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, %{hash: hash}} ->
      Block.ByHash.request(%{id: id, hash: hash})
    end)
  end
end
