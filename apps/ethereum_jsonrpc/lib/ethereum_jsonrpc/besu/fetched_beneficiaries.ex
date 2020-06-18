defmodule EthereumJSONRPC.Besu.FetchedBeneficiaries do
  @moduledoc """
  Beneficiaries and errors from batch requests to `trace_block`.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @doc """
  Converts `responses` to `EthereumJSONRPC.FetchedBeneficiaries.t()`.

  responses - List with trace_block responses
  id_to_params - Maps request id to query params

  ## Examples
    iex> EthereumJSONRPC.Besu.FetchedBeneficiaries.from_responses(
    ...>   [
    ...>     %{
    ...>       id: 0,
    ...>       result: [
    ...>         %{
    ...>           "action" => %{"author" => "0x1", "rewardType" => "external", "value" => "0x0"},
    ...>           "blockHash" => "0xFFF",
    ...>           "blockNumber" => 12,
    ...>           "result" => nil,
    ...>           "subtraces" => 0,
    ...>           "traceAddress" => [],
    ...>           "transactionHash" => nil,
    ...>           "transactionPosition" => nil,
    ...>           "type" => "reward"
    ...>         },
    ...>         %{
    ...>           "action" => %{"author" => "0x2", "rewardType" => "external", "value" => "0x0"},
    ...>           "blockHash" => "0xFFF",
    ...>           "blockNumber" => 12,
    ...>           "result" => nil,
    ...>           "subtraces" => 0,
    ...>           "traceAddress" => [],
    ...>           "transactionHash" => nil,
    ...>           "transactionPosition" => nil,
    ...>           "type" => "reward"
    ...>         }
    ...>       ]
    ...>     }
    ...>   ],
    ...>   %{0 => %{block_quantity: "0xC"}}
    ...> )
    %EthereumJSONRPC.FetchedBeneficiaries{
      errors: [],
      params_set: #MapSet<[
        %{
          address_hash: "0x1",
          address_type: :validator,
          block_hash: "0xFFF",
          block_number: 12,
          reward: "0x0"
        },
        %{
          address_hash: "0x2",
          address_type: :emission_funds,
          block_hash: "0xFFF",
          block_number: 12,
          reward: "0x0"
        }
      ]>
    }
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
    traces
    |> Stream.filter(&(&1["type"] == "reward"))
    |> Stream.with_index()
    |> Enum.reduce(MapSet.new(), fn {trace, index}, acc ->
      MapSet.union(acc, trace_to_params_set(trace, block_number, index))
    end)
  end

  defp trace_to_params_set(
         %{
           "action" => %{
             "rewardType" => reward_type,
             "author" => address_hash_data,
             "value" => reward_value
           },
           "blockHash" => block_hash,
           "blockNumber" => block_number
         },
         block_number,
         index
       )
       when is_integer(block_number) and reward_type in ~w(block external uncle) do
    MapSet.new([
      %{
        address_hash: address_hash_data,
        block_hash: block_hash,
        block_number: block_number,
        reward: reward_value,
        address_type: get_address_type(reward_type, index)
      }
    ])
  end

  # Beneficiary's address type will depend on the responses' action.rewardType,
  # which will vary depending on which network is being indexed
  #
  # On POA networks, rewardType will always be external and the type of the address being
  # rewarded will depend on its position.
  # First address will always be the validator's while the second will be the EmissionsFunds address
  #
  # On PoW networks, like Ethereum, the reward type will already specify the type for the
  # address being rewarded
  # The rewardType "block" will show the reward for the consensus block validator
  # The rewardType "uncle" will show reward for validating an uncle block
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 0, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 1, do: :emission_funds
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 2, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 3, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 4, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 5, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 6, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 7, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 8, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 9, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 10, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 11, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 12, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 13, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 14, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 15, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 16, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 17, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 18, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 19, do: :validator
  defp get_address_type(reward_type, index) when reward_type == "external" and index == 20, do: :validator
  defp get_address_type(reward_type, _index) when reward_type == "block", do: :validator
  defp get_address_type(reward_type, _index) when reward_type == "uncle", do: :uncle
  defp get_address_type(reward_type, _index) when reward_type == "emptyStep", do: :validator
end
