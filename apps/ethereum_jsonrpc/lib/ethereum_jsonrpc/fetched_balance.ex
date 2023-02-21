defmodule EthereumJSONRPC.FetchedBalance do
  @moduledoc """
  A single balance fetched from `eth_getBalance`.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @type params :: %{address_hash: EthereumJSONRPC.hash(), block_number: non_neg_integer(), value: non_neg_integer()}
  @type error :: %{code: integer(), message: String.t(), data: %{block_quantity: String.t(), hash: String.t()}}

  @doc """
  Converts `response` to balance params or annotated error.
  """

  @spec from_response(%{id: id, result: String.t()}, %{id => %{block_quantity: block_quantity, hash_data: hash_data}}) ::
          {:ok, params()}
        when id: non_neg_integer(), block_quantity: String.t(), hash_data: String.t()
  def from_response(%{id: id, result: fetched_balance_quantity}, id_to_params)
      when not is_nil(fetched_balance_quantity) and is_map(id_to_params) do
    %{block_quantity: block_quantity, hash_data: hash_data} = Map.fetch!(id_to_params, id)

    {:ok,
     %{
       address_hash: hash_data,
       block_number: quantity_to_integer(block_quantity),
       value: quantity_to_integer(fetched_balance_quantity)
     }}
  end

  @spec from_response(
          %{
            id: id,
            error: %{code: code, message: message}
          },
          %{id => %{block_quantity: block_quantity, hash_data: hash_data}}
        ) :: {:error, %{code: code, message: message, data: %{block_quantity: block_quantity, hash: hash_data}}}
        when id: non_neg_integer(),
             code: integer(),
             message: String.t(),
             block_quantity: String.t(),
             hash_data: String.t()
  def from_response(%{id: id, error: %{code: code, message: message} = error}, id_to_params)
      when is_integer(code) and is_binary(message) and is_map(id_to_params) do
    %{block_quantity: block_quantity, hash_data: hash_data} = Map.fetch!(id_to_params, id)

    annotated_error = Map.put(error, :data, %{block_quantity: block_quantity, hash_data: hash_data})

    {:error, annotated_error}
  end

  @spec request(%{id: id, block_quantity: block_quantity, hash_data: hash_data}) :: %{
          jsonrpc: String.t(),
          id: id,
          method: String.t(),
          params: [hash_data | block_quantity]
        }
        when id: EthereumJSONRPC.request_id(),
             block_quantity: EthereumJSONRPC.quantity(),
             hash_data: EthereumJSONRPC.hash()
  def request(%{id: id, block_quantity: block_quantity, hash_data: hash_data}) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getBalance", params: [hash_data, block_quantity]})
  end
end
