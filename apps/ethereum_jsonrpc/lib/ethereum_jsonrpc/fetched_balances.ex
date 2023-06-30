defmodule EthereumJSONRPC.FetchedBalances do
  @moduledoc """
  Balance params and errors from a batch request from `eth_getBalance`.
  """

  alias EthereumJSONRPC.FetchedBalance

  defstruct params_list: [],
            errors: []

  @typedoc """
   * `params_list` - all the balance params from requests that succeeded in the batch.
   * `errors` - all the errors from requests that failed in the batch.
  """
  @type t :: %__MODULE__{params_list: [FetchedBalance.params()], errors: [FetchedBalance.error()]}

  @doc """
  Converts `responses` to `t/0`.
  """
  def from_responses(responses, id_to_params) do
    responses
    |> EthereumJSONRPC.sanitize_responses(id_to_params)
    |> Enum.map(&FetchedBalance.from_response(&1, id_to_params))
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

  @doc """
  `eth_getBalance` requests for `id_to_params`.
  """
  @spec requests(%{id => %{block_quantity: block_quantity, hash_data: hash_data}}) :: [
          %{jsonrpc: String.t(), id: id, method: String.t(), params: [hash_data | block_quantity]}
        ]
        when id: EthereumJSONRPC.request_id(),
             block_quantity: EthereumJSONRPC.quantity(),
             hash_data: EthereumJSONRPC.hash()
  def requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, %{block_quantity: block_quantity, hash_data: hash_data}} ->
      FetchedBalance.request(%{id: id, block_quantity: block_quantity, hash_data: hash_data})
    end)
  end
end
