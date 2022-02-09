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
          required(:method_id) => String.t(),
          required(:args) => [term()],
          optional(:block_number) => EthereumJSONRPC.block_number()
        }

  @typedoc """
  Result of calling a smart contract function.
  """
  @type call_result :: {:ok, term()} | {:error, String.t()}

  @spec execute_contract_functions([call()], [map()], EthereumJSONRPC.json_rpc_named_arguments(), true | false) :: [
          call_result()
        ]
  def execute_contract_functions(requests, abi, json_rpc_named_arguments, leave_error_as_map \\ false) do
    parsed_abi =
      abi
      |> ABI.parse_specification()

    functions = Enum.into(parsed_abi, %{}, &{&1.method_id, &1})

    requests_with_index = Enum.with_index(requests)

    indexed_responses =
      requests_with_index
      |> Enum.map(fn {%{contract_address: contract_address, method_id: target_method_id, args: args} = request, index} ->
        function =
          functions
          |> define_function(target_method_id)
          |> Map.drop([:method_id])

        formatted_args = format_args(function, args)

        function
        |> Encoder.encode_function_call(formatted_args)
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
          selectors = define_selectors(parsed_abi, method_id)

          {^index, result} = Encoder.decode_result(response, selectors, leave_error_as_map)
          result
      end
    end)
  rescue
    error ->
      Enum.map(requests, fn _ -> format_error(error) end)
  end

  defp format_args(function, args) do
    types = function.types

    args
    |> Enum.with_index()
    |> Enum.map(fn {arg, index} ->
      type = Enum.at(types, index)

      convert_string_to_array(type, arg)
    end)
  end

  defp convert_string_to_array(type, arg) do
    case type do
      {:array, {:int, _size}} ->
        convert_int_string_to_array(arg)

      {:array, {:uint, _size}} ->
        convert_int_string_to_array(arg)

      {:array, _} ->
        convert_string_to_array(arg)

      _ ->
        arg
    end
  end

  defp convert_int_string_to_array(arg) when is_nil(arg), do: true

  defp convert_int_string_to_array(arg) when is_list(arg), do: convert_int_string_to_array_inner(arg)

  defp convert_int_string_to_array(arg) when not is_nil(arg) do
    cond do
      String.starts_with?(arg, "[") && String.ends_with?(arg, "]") ->
        arg
        |> String.trim_leading("[")
        |> String.trim_trailing("]")
        |> String.split(",")
        |> convert_int_string_to_array_inner()

      arg !== "" ->
        arg
        |> String.split(",")
        |> convert_int_string_to_array_inner()

      true ->
        []
    end
  end

  defp convert_int_string_to_array_inner(arg) do
    arg
    |> Enum.map(fn el ->
      {int, _} = Integer.parse(el)
      int
    end)
  end

  defp convert_string_to_array(arg) when is_nil(arg), do: true

  defp convert_string_to_array(arg) when is_list(arg), do: arg

  defp convert_string_to_array(arg) when not is_nil(arg) do
    cond do
      String.starts_with?(arg, "[") && String.ends_with?(arg, "]") ->
        arg
        |> String.trim_leading("[")
        |> String.trim_trailing("]")
        |> String.split(",")

      arg !== "" ->
        String.split(arg, ",")

      true ->
        []
    end
  end

  defp define_function(functions, target_method_id) do
    {_, function} =
      Enum.find(functions, fn {method_id, _func} ->
        if method_id do
          Base.encode16(method_id, case: :lower) == target_method_id || method_id == target_method_id
        else
          method_id == target_method_id
        end
      end)

    function
  end

  defp define_selectors(parsed_abi, method_id) do
    Enum.filter(parsed_abi, fn p_abi ->
      if p_abi.method_id do
        Base.encode16(p_abi.method_id, case: :lower) == method_id || p_abi.method_id == method_id
      else
        p_abi.method_id == method_id
      end
    end)
  end

  def eth_call_request(data, contract_address, id, block_number, from) do
    block =
      case block_number do
        nil -> "latest"
        block_number -> integer_to_quantity(block_number)
      end

    full_params = %{
      id: id,
      method: "eth_call",
      params: [%{to: contract_address, data: data, from: from}, block]
    }

    request(full_params)
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
    error
    |> Map.put(:hide_url, true)
    |> Exception.message()
    |> format_error()
  end
end
