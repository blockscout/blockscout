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
    functions =
      abi
      |> ABI.parse_specification()
      |> Enum.into(%{}, &{&1.function, &1})

    requests_with_index = Enum.with_index(requests)

    indexed_responses =
      requests_with_index
      |> Enum.map(fn {%{contract_address: contract_address, function_name: function_name, args: args} = request, index} ->
        functions[function_name]
        |> Encoder.encode_function_call(args)
        |> eth_call_request(contract_address, index, Map.get(request, :block_number))
      end)
      |> json_rpc(json_rpc_named_arguments)
      |> case do
        {:ok, responses} -> responses
        {:error, {:bad_gateway, _request_url}} -> raise "Bad gateway"
        {:error, reason} when is_atom(reason) -> raise Atom.to_string(reason)
        {:error, error} -> raise error
      end
      |> Enum.into(%{}, &{&1.id, &1})

    Enum.map(requests_with_index, fn {%{function_name: function_name}, index} ->
      indexed_responses[index]
      |> case do
        nil ->
          {:error, "No result"}

        response ->
          {^index, result} = Encoder.decode_result(response, functions[function_name])
          result
      end
    end)
  rescue
    error ->
      Enum.map(requests, fn _ -> format_error(error) end)
  end

  defp eth_call_request(data, contract_address, id, block_number) do
    block =
      case block_number do
        nil -> "latest"
        block_number -> integer_to_quantity(block_number)
      end

    request(%{
      id: id,
      method: "eth_call",
      params: [%{to: contract_address, data: data}, block]
    })
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
