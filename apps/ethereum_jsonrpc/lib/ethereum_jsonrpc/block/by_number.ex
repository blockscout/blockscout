defmodule EthereumJSONRPC.Block.ByNumber do
  @moduledoc """
  Block format as returned by [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  def request(%{id: id, number: number}) do
    if is_list(number) do
      EthereumJSONRPC.request(%{id: id, method: "eth_getBlockByNumber", params: [integer_to_quantity(Enum.at(number, String.to_integer(System.get_env("CHAIN_INDEX")))), true]})
    else
      EthereumJSONRPC.request(%{id: id, method: "eth_getBlockByNumber", params: [integer_to_quantity(number), true]})
    end
    EthereumJSONRPC.request(%{id: id, method: "eth_getBlockByNumber", params: [integer_to_quantity(number), true]})
  end
end
