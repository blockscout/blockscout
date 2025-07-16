defmodule EthereumJSONRPC.Nonce do
  @moduledoc """
  A single code fetched from `eth_getTransactionCount`.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  alias EthereumJSONRPC.FetchedCode

  @type params :: %{address: EthereumJSONRPC.address(), block_number: non_neg_integer(), nonce: non_neg_integer()}
  @type error :: FetchedCode.error()

  @doc """
    Converts a JSON-RPC response of `eth_getTransactionCount` to code params or an annotated error.

    This function handles two types of responses:
    1. Successful responses with fetched code.
    2. Error responses.

    ## Parameters
    - `response`: A map containing either a successful result or an error.
    - `id_to_params`: A map of request IDs to their corresponding parameters.

    ## Returns
    - `{:ok, params()}` for successful responses, where `params()` is a map
      containing the address, block number, and fetched code.
    - `{:error, error()}` for error responses, where `error()` is a map
      containing the error code, message, and additional data.

    ## Examples
        iex> # Successful response:
        iex> response = %{id: 1, result: "0x2"}
        iex> id_to_params = %{1 => %{block_quantity: "0x1", address: "0xabc"}}
        iex> Nonce.from_response(response, id_to_params)
        {:ok, %{address: "0xabc", block_number: 1, nonce: 2}}
        iex> # Error response:
        iex> response = %{id: 1, error: %{code: 100, message: "Error"}}
        iex> id_to_params = %{1 => %{block_quantity: "0x1", address: "0xabc"}}
        iex> Nonce.from_response(response, id_to_params)
        {:error, %{code: 100, message: "Error", data: %{block_quantity: "0x1", address: "0xabc"}}}
  """
  @spec from_response(%{id: EthereumJSONRPC.request_id(), result: String.t()}, %{
          non_neg_integer() => %{block_quantity: String.t(), address: String.t()}
        }) :: {:ok, params()}
  def from_response(%{id: id, result: nonce_hex}, id_to_params) when is_map(id_to_params) do
    %{block_quantity: block_quantity, address: address} = Map.fetch!(id_to_params, id)

    {:ok,
     %{
       address: address,
       block_number: quantity_to_integer(block_quantity),
       nonce: quantity_to_integer(nonce_hex)
     }}
  end

  @spec from_response(%{id: EthereumJSONRPC.request_id(), error: %{code: integer(), message: String.t()}}, %{
          non_neg_integer() => %{block_quantity: String.t(), address: String.t()}
        }) :: {:error, error()}
  def from_response(%{id: _id, error: %{code: code, message: message}} = response, id_to_params)
      when is_integer(code) and is_binary(message) and is_map(id_to_params) do
    FetchedCode.from_response(response, id_to_params)
  end

  @doc """
    Creates a standardized JSON-RPC request structure to fetch contract code using `eth_getTransactionCount`.

    ## Parameters
    - `id`: The request identifier.
    - `block_quantity`: The block number or tag (e.g., "latest") for which to
      fetch the code.
    - `address`: The address of the contract whose code is to be fetched.

    ## Returns
    A map representing a JSON-RPC request with the following structure:
    - `jsonrpc`: The JSON-RPC version (always "2.0").
    - `id`: The request identifier passed in.
    - `method`: The RPC method name (always "eth_getTransactionCount").
    - `params`: A list containing the contract address and block identifier.
  """
  @spec request(%{id: id, block_quantity: block_quantity, address: address}) :: %{
          jsonrpc: String.t(),
          id: id,
          method: String.t(),
          params: [address | block_quantity]
        }
        when id: EthereumJSONRPC.request_id(),
             block_quantity: EthereumJSONRPC.quantity(),
             address: EthereumJSONRPC.address()
  def request(%{id: id, block_quantity: block_quantity, address: address}) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getTransactionCount", params: [address, block_quantity]})
  end
end
