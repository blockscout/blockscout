defmodule EthereumJSONRPC.FetchedCode do
  @moduledoc """
  A single code fetched from `eth_getCode`.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @type params :: %{address: EthereumJSONRPC.address(), block_number: non_neg_integer(), code: non_neg_integer()}
  @type error :: %{code: integer(), message: String.t(), data: %{block_quantity: String.t(), address: String.t()}}

  @doc """
  Converts `response` to code params or annotated error.
  """

  def from_response(%{id: id, result: fetched_code}, id_to_params) when is_map(id_to_params) do
    %{block_quantity: block_quantity, address: address} = Map.fetch!(id_to_params, id)

    {:ok,
     %{
       address: address,
       block_number: quantity_to_integer(block_quantity),
       code: fetched_code
     }}
  end

  @spec from_response(%{id: id, result: String.t()}, %{id => %{block_quantity: block_quantity, address: address}}) ::
          {:ok, params()}
        when id: non_neg_integer(), block_quantity: String.t(), address: String.t()
  def from_response(%{id: id, error: %{code: code, message: message} = error}, id_to_params)
      when is_integer(code) and is_binary(message) and is_map(id_to_params) do
    %{block_quantity: block_quantity, address: address} = Map.fetch!(id_to_params, id)

    annotated_error = Map.put(error, :data, %{block_quantity: block_quantity, address: address})

    {:error, annotated_error}
  end

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
