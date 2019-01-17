defmodule EthereumJSONRPC.FetchedCodes do
  @moduledoc """
  Code params and errors from a batch request from `eth_getCode`.
  """

  alias EthereumJSONRPC.FetchedCode

  defstruct params_list: [],
            errors: []

  @typedoc """
   * `params_list` - all the code params from requests that succeeded in the batch.
   * `errors` - all the errors from requests that failed in the batch.
  """
  @type t :: %__MODULE__{params_list: [FetchedCode.params()], errors: [FetchedCode.error()]}

  @doc """
  `eth_getCode` requests for `id_to_params`.
  """
  @spec requests(%{id => %{block_quantity: block_quantity, address: address}}) :: [
          %{jsonrpc: String.t(), id: id, method: String.t(), params: [address | block_quantity]}
        ]
        when id: EthereumJSONRPC.request_id(),
             block_quantity: EthereumJSONRPC.quantity(),
             address: EthereumJSONRPC.address()
  def requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, %{block_quantity: block_quantity, address: address}} ->
      FetchedCode.request(%{id: id, block_quantity: block_quantity, address: address})
    end)
  end

  @doc """
  Converts `responses` to `t/0`.
  """
  def from_responses(responses, id_to_params) do
    responses
    |> Enum.map(&FetchedCode.from_response(&1, id_to_params))
    |> Enum.reduce(
      %__MODULE__{},
      fn
        {:ok, params}, %__MODULE__{params_list: params_list} = acc ->
          %__MODULE__{acc | params_list: [params | params_list]}

        {:error, reason}, %__MODULE__{errors: errors} = acc ->
          %__MODULE__{acc | errors: [reason | errors]}
      end
    )
  end
end
