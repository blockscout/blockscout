defmodule EthereumJSONRPC.FetchedCode do
  @moduledoc """
  A single code fetched from `eth_getCode`.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @type params :: %{address: EthereumJSONRPC.address(), block_number: non_neg_integer(), code: non_neg_integer()}
  @type error :: %{code: integer(), message: String.t(), data: %{block_quantity: String.t(), address: String.t()}}

  @doc """
    Converts a JSON-RPC response of `eth_getCode` to code params or an annotated error.

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
        iex> response = %{id: 1, result: "0x123"}
        iex> id_to_params = %{1 => %{block_quantity: "0x1", address: "0xabc"}}
        iex> FetchedCode.from_response(response, id_to_params)
        {:ok, %{address: "0xabc", block_number: 1, code: "0x123"}}
        iex> # Error response:
        iex> response = %{id: 1, error: %{code: 100, message: "Error"}}
        iex> id_to_params = %{1 => %{block_quantity: "0x1", address: "0xabc"}}
        iex> FetchedCode.from_response(response, id_to_params)
        {:error, %{code: 100, message: "Error", data: %{block_quantity: "0x1", address: "0xabc"}}}
  """
  @spec from_response(%{id: EthereumJSONRPC.request_id(), result: String.t()}, %{
          non_neg_integer() => %{block_quantity: String.t(), address: String.t()}
        }) :: {:ok, params()}
  def from_response(%{id: id, result: fetched_code}, id_to_params) when is_map(id_to_params) do
    %{block_quantity: block_quantity, address: address} = Map.fetch!(id_to_params, id)

    {:ok,
     %{
       address: address,
       block_number: quantity_to_integer(block_quantity),
       code: fetched_code
     }}
  end

  @spec from_response(%{id: EthereumJSONRPC.request_id(), error: %{code: integer(), message: String.t()}}, %{
          non_neg_integer() => %{block_quantity: String.t(), address: String.t()}
        }) :: {:error, error()}
  def from_response(%{id: id, error: %{code: code, message: message} = error}, id_to_params)
      when is_integer(code) and is_binary(message) and is_map(id_to_params) do
    %{block_quantity: block_quantity, address: address} = Map.fetch!(id_to_params, id)

    annotated_error = Map.put(error, :data, %{block_quantity: block_quantity, address: address})

    {:error, annotated_error}
  end

  @doc """
    Creates a standardized JSON-RPC request structure to fetch contract code using `eth_getCode`.

    ## Parameters
    - `id`: The request identifier.
    - `block_quantity`: The block number or tag (e.g., "latest") for which to
      fetch the code.
    - `address`: The address of the contract whose code is to be fetched.

    ## Returns
    A map representing a JSON-RPC request with the following structure:
    - `jsonrpc`: The JSON-RPC version (always "2.0").
    - `id`: The request identifier passed in.
    - `method`: The RPC method name (always "eth_getCode").
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
    EthereumJSONRPC.request(%{id: id, method: "eth_getCode", params: [address, block_quantity]})
  end
end
