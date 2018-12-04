defmodule EthereumJSONRPC.Parity.FetchedBeneficiaries do
  @moduledoc """
  Beneficiaries and errors from batch requests to `trace_block`.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @doc """
  Converts `responses` to `t/0`.
  """
  def from_responses(responses, id_to_params) when is_list(responses) and is_map(id_to_params) do
    responses
    |> Enum.map(&response_to_params_set(&1, id_to_params))
    |> Enum.reduce(
      %EthereumJSONRPC.FetchedBeneficiaries{},
      fn
        {:ok, params_set}, %EthereumJSONRPC.FetchedBeneficiaries{params_set: acc_params_set} = acc ->
          %EthereumJSONRPC.FetchedBeneficiaries{acc | params_set: MapSet.union(acc_params_set, params_set)}

        {:error, reason}, %EthereumJSONRPC.FetchedBeneficiaries{errors: errors} = acc ->
          %EthereumJSONRPC.FetchedBeneficiaries{acc | errors: [reason | errors]}
      end
    )
  end

  @doc """
  `trace_block` requests for `id_to_params`.
  """
  def requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, %{block_quantity: block_quantity}} ->
      request(%{id: id, block_quantity: block_quantity})
    end)
  end

  @spec response_to_params_set(%{id: id, result: nil}, %{id => %{block_quantity: block_quantity}}) ::
          {:error, %{code: 404, message: String.t(), data: %{block_quantity: block_quantity}}}
        when id: non_neg_integer(), block_quantity: String.t()
  defp response_to_params_set(%{id: id, result: nil}, id_to_params) when is_map(id_to_params) do
    %{block_quantity: block_quantity} = Map.fetch!(id_to_params, id)

    {:error, %{code: 404, message: "Not Found", data: %{block_quantity: block_quantity}}}
  end

  @spec response_to_params_set(%{id: id, result: list(map())}, %{id => %{block_quantity: block_quantity}}) ::
          {:ok, MapSet.t(EthereumJSONRPC.FetchedBeneficiary.params())}
        when id: non_neg_integer(), block_quantity: String.t()
  defp response_to_params_set(%{id: id, result: traces}, id_to_params) when is_list(traces) and is_map(id_to_params) do
    %{block_quantity: block_quantity} = Map.fetch!(id_to_params, id)
    block_number = quantity_to_integer(block_quantity)
    params_set = traces_to_params_set(traces, block_number)

    {:ok, params_set}
  end

  @spec response_to_params_set(%{id: id, error: %{code: code, message: message}}, %{
          id => %{block_quantity: block_quantity}
        }) :: {:error, %{code: code, message: message, data: %{block_quantity: block_quantity}}}
        when id: non_neg_integer(), code: integer(), message: String.t(), block_quantity: String.t()
  defp response_to_params_set(%{id: id, error: error}, id_to_params) when is_map(id_to_params) do
    %{block_quantity: block_quantity} = Map.fetch!(id_to_params, id)

    annotated_error = Map.put(error, :data, %{block_quantity: block_quantity})

    {:error, annotated_error}
  end

  defp request(%{id: id, block_quantity: block_quantity}) when is_integer(id) and is_binary(block_quantity) do
    EthereumJSONRPC.request(%{id: id, method: "trace_block", params: [block_quantity]})
  end

  defp traces_to_params_set(traces, block_number) when is_list(traces) and is_integer(block_number) do
    Enum.reduce(traces, MapSet.new(), fn trace, acc ->
      MapSet.union(acc, trace_to_params_set(trace, block_number))
    end)
  end

  defp trace_to_params_set(%{"action" => %{"callType" => _}, "blockNumber" => block_number}, block_number),
    do: MapSet.new()

  defp trace_to_params_set(%{"type" => type, "blockNumber" => block_number}, block_number)
       when type in ~w(create suicide),
       do: MapSet.new()

  defp trace_to_params_set(
         %{
           "action" => %{"rewardType" => reward_type, "author" => address_hash_data},
           "blockNumber" => block_number
         },
         block_number
       )
       when is_integer(block_number) and reward_type in ~w(block external uncle) do
    MapSet.new([%{address_hash: address_hash_data, block_number: block_number}])
  end
end
