defmodule EthereumJSONRPC.Receipts.ByTransactionHash do
  @moduledoc """
    Provides functionality to compose JSON-RPC requests for fetching Ethereum transaction receipt by the transaction hash.
  """

  alias EthereumJSONRPC.Transport

  @doc """
    Creates a request to fetch a transaction receipt by its hash using `eth_getTransactionReceipt`.

    ## Parameters
    - `id`: Request identifier
    - `transaction_hash`: Hash of the transaction to fetch the receipt for

    ## Returns
    - A JSON-RPC request map for `eth_getTransactionReceipt`
  """
  @spec request(EthereumJSONRPC.request_id(), EthereumJSONRPC.hash()) :: Transport.request()
  def request(id, transaction_hash) when is_integer(id) and is_binary(transaction_hash) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getTransactionReceipt", params: [transaction_hash]})
  end
end
