defmodule EthereumJSONRPC.Receipts.ByBlockNumber do
  @moduledoc """
    Provides functionality to compose JSON-RPC requests for fetching Ethereum block receipts by the block number.
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias EthereumJSONRPC.Transport

  @doc """
      Creates a request to fetch all transaction receipts for a block using
      `eth_getBlockReceipts`.

      ## Parameters
      - `map`: A map containing:
        - `id`: Request identifier
        - `number`: Block number as integer or hex string

      ## Returns
      - A JSON-RPC request map for `eth_getBlockReceipts`
  """
  @spec request(%{id: EthereumJSONRPC.request_id(), number: EthereumJSONRPC.block_number() | EthereumJSONRPC.quantity()}) ::
          Transport.request()
  def request(%{id: id, number: number}) when is_integer(number) do
    block_number = integer_to_quantity(number)

    EthereumJSONRPC.request(%{id: id, method: "eth_getBlockReceipts", params: [block_number]})
  end

  def request(%{id: id, number: number}) when is_binary(number) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getBlockReceipts", params: [number]})
  end
end
