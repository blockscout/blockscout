defmodule EthereumJSONRPC.Contract do
  @moduledoc """
  Smart contract functions executed by `eth_call`.
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1, json_rpc: 2, request: 1]

  alias EthereumJSONRPC.Encoder

  @typedoc """
  Call to a smart contract function.

  * `:block_number` - the block in which to execute the function. Defaults to the `nil` to indicate
  the latest block as determined by the remote node, which may differ from the latest block number
  in `Explorer.Chain`.
  """
  @type call :: %{
          required(:contract_address) => String.t(),
          required(:function_name) => String.t(),
          required(:args) => [term()],
          optional(:block_number) => EthereumJSONRPC.block_number()
        }

  @typedoc """
  Result of calling a smart contract function.
  """
  @type call_result :: {:ok, term()} | {:error, String.t()}

  @spec execute_contract_functions([call()], [map()], EthereumJSONRPC.json_rpc_named_arguments()) :: [call_result()]
  def execute_contract_functions(requests, abi, json_rpc_named_arguments) do
    parsed_abi =
      abi
      |> ABI.parse_specification()

    functions = Enum.into(parsed_abi, %{}, &{&1.method_id, &1})

    requests_with_index = Enum.with_index(requests)

    indexed_responses =
      requests_with_index
      |> Enum.map(fn {%{contract_address: contract_address, method_id: target_method_id, args: args} = request, index} ->
        {_, function} =
          Enum.find(functions, fn {method_id, _func} ->
            if method_id do
              Base.encode16(method_id, case: :lower) == target_method_id || method_id == target_method_id
            else
              method_id == target_method_id
            end
          end)

        function
        |> Map.drop([:method_id])
        |> Encoder.encode_function_call(args)
        |> eth_call_request(contract_address, index, Map.get(request, :block_number), Map.get(request, :from))
      end)
      |> json_rpc(json_rpc_named_arguments)
      |> case do
        {:ok, responses} -> responses
        {:error, {:bad_gateway, _request_url}} -> raise "Bad gateway"
        {:error, reason} when is_atom(reason) -> raise Atom.to_string(reason)
        {:error, error} -> raise error
      end
      |> Enum.into(%{}, &{&1.id, &1})

    Enum.map(requests_with_index, fn {%{method_id: method_id}, index} ->
      indexed_responses[index]
      |> case do
        nil ->
          {:error, "No result"}

        response ->
          selectors =
            Enum.filter(parsed_abi, fn p_abi ->
              if method_id && p_abi.method_id do
                Base.encode16(p_abi.method_id, case: :lower) == method_id || p_abi.method_id == method_id
              else
                p_abi.method_id == method_id
              end
            end)

          {^index, result} = Encoder.decode_result(response, selectors)
          result
      end
    end)
  rescue
    error ->
      Enum.map(requests, fn _ -> format_error(error) end)
  end

  def eth_call_request(data, contract_address, id, block_number, from) do
    block =
      case block_number do
        nil -> "latest"
        block_number -> integer_to_quantity(block_number)
      end

    request(%{
      id: id,
      method: "eth_call",
      params: [%{to: contract_address, data: data, from: from}, block]
    })
  end

  def eth_get_storage_at_request(contract_address, storage_pointer, block_number, json_rpc_named_arguments) do
    block =
      case block_number do
        nil -> "latest"
        block_number -> integer_to_quantity(block_number)
      end

    result =
      %{id: 0, method: "eth_getStorageAt", params: [contract_address, storage_pointer, block]}
      |> request()
      |> json_rpc(json_rpc_named_arguments)

    case result do
      {:ok, storage_value} -> {:ok, storage_value}
      other -> other
    end
  end

  defp format_error(message) when is_binary(message) do
    {:error, message}
  end

  defp format_error(%{message: error_message}) do
    format_error(error_message)
  end

  defp format_error(error) do
    format_error(Exception.message(error))
  end
end
