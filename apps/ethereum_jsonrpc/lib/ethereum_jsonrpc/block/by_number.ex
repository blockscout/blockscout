defmodule EthereumJSONRPC.Block.ByNumber do
  @moduledoc """
    Provides functionality to compose JSON-RPC requests for fetching Ethereum blocks by their number.

    Block format as returned by [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC/e8e0771b9f3677693649d945956bc60e886ceb2b#eth_getblockbyhash)
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias EthereumJSONRPC.Transport

  @doc """
    Creates a request to fetch a block by its number using `eth_getBlockByNumber`.

    ## Parameters
    - `map`: A map containing:
      - `id`: Request identifier
      - `number`: Block number as integer or hex string
    - `hydrated`: When true, returns full transaction objects. When false, returns
      only transaction hashes. Defaults to true.
    - `int_to_qty`: When true, converts integer block numbers to hex format.
      When false, uses the number as-is. Defaults to true.

    ## Returns
    - A JSON-RPC request map for `eth_getBlockByNumber`
  """
  @spec request(%{id: non_neg_integer(), number: non_neg_integer() | binary()}, boolean(), boolean()) ::
          Transport.request()
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
