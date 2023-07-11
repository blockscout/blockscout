defmodule EthereumJSONRPC.Block.ByNumber do
  @moduledoc """
  Block format as returned by [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  def request(%{id: id, number: number}, hydrated \\ true, int_to_qty \\ true) do
    block_number =
      if int_to_qty do
        integer_to_quantity(number)
      else
        number
      end

    EthereumJSONRPC.request(%{id: id, method: "eth_getBlockByNumber", params: [block_number, hydrated]})
  end
end
