defmodule EthereumJSONRPC.Block.ByTag do
  @moduledoc """
  Block format returned by [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbyhash)
  when used with a semantic tag name instead of a number.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  alias EthereumJSONRPC.Blocks

  @doc """
    Creates a JSON-RPC request to fetch a block by its semantic tag.

    ## Parameters
    - `%{id: id, tag: tag}`: Request parameters where:
      - `id`: Request identifier as a binary or non-negative integer
      - `tag`: Semantic tag (e.g. "latest", "earliest", "pending") as a binary string

    ## Returns
    A JSON-RPC 2.0 request map for the `eth_getBlockByNumber` method with `false` for transaction details
  """
  @spec request(%{:id => binary() | non_neg_integer(), :tag => binary()}) :: EthereumJSONRPC.Transport.request()
  def request(%{id: id, tag: tag}) when is_binary(tag) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getBlockByNumber", params: [tag, false]})
  end

  @doc """
    Extracts the block number from a JSON-RPC response for a block request by tag.

    Handles various response formats and error cases from eth_getBlockByNumber requests.

    ## Parameters
    - `result`: The JSON-RPC response which can be:
      - `{:ok, %{"number" => number}}` - Successful response with block number
      - `{:ok, %Blocks{blocks_params: params}}` - Processed blocks response
      - `{:ok, nil}` - No block found
      - `{:error, map()}` - Error response

    ## Returns
    - `{:ok, number}` - Successfully extracted block number
    - `{:error, :not_found}` - Block not found or empty response
    - `{:error, :invalid_tag}` - Invalid tag parameter (-32602 error)
    - `{:error, term()}` - Other error from request
  """
  @spec number_from_result(EthereumJSONRPC.Transport.result()) ::
          {:ok, non_neg_integer()} | {:error, reason :: :invalid_tag | :not_found | term()}
  def number_from_result(result)

  def number_from_result({:ok, %{"number" => nil}}), do: {:error, :not_found}

  def number_from_result({:ok, %{"number" => quantity}}) when is_binary(quantity) do
    {:ok, quantity_to_integer(quantity)}
  end

  def number_from_result({:ok, %Blocks{blocks_params: []}}), do: {:error, :not_found}

  def number_from_result({:ok, %Blocks{blocks_params: [%{number: number}]}}), do: {:ok, number}

  def number_from_result({:ok, nil}), do: {:error, :not_found}

  def number_from_result({:error, %{"code" => -32602}}), do: {:error, :invalid_tag}
  def number_from_result({:error, _} = error), do: error
end
