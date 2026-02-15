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
          optional(:block_number) => EthereumJSONRPC.block_number() | nil
        }

  @typedoc """
  Result of calling a smart contract function.
  """
  @type call_result :: {:ok, term()} | {:error, String.t()}

  @spec execute_contract_functions([call()], [map()], EthereumJSONRPC.json_rpc_named_arguments(), true | false) :: [
          call_result()
        ]
  def execute_contract_functions(requests, abi, json_rpc_named_arguments, leave_error_as_map \\ false) do
    parsed_abi = ABI.parse_specification(abi)
    functions = Enum.into(parsed_abi, %{}, &{&1.method_id, &1})
    requests_with_index = Enum.with_index(requests)

    {valid_requests, local_errors} =
      requests_with_index
      |> build_rpc_requests(functions)
      |> Enum.split_with(&match?({:ok, _}, &1))

    local_error_map =
      local_errors
      |> Enum.into(%{}, fn {:error, {index, message}} -> {index, {:local_error, message}} end)

    indexed_responses =
      case valid_requests do
        [] ->
          {:ok, local_error_map}

        _ ->
          valid_requests
          |> Enum.map(fn {:ok, request} -> request end)
          |> safe_json_rpc(json_rpc_named_arguments)
          |> handle_batch_response()
          |> merge_local_errors(local_error_map)
      end

    process_responses(indexed_responses, requests_with_index, parsed_abi, requests, leave_error_as_map)
  end

  defp build_rpc_requests(requests_with_index, functions) do
    Enum.map(requests_with_index, fn {%{contract_address: contract_address, method_id: target_method_id, args: args} =
                                        request, index} ->
      function =
        functions
        |> define_function(target_method_id)
        |> Map.drop([:method_id])

      with {:ok, formatted_args} <- safe_format_args(function, args),
           {:ok, encoded} <- safe_encode_function_call(function, formatted_args) do
        {:ok,
         eth_call_request(encoded, contract_address, index, Map.get(request, :block_number), Map.get(request, :from))}
      else
        {:error, message} -> {:error, {index, message}}
      end
    end)
  end

  defp merge_local_errors({:ok, response_map}, local_error_map), do: {:ok, Map.merge(response_map, local_error_map)}
  defp merge_local_errors(other, _local_error_map), do: other

  defp handle_batch_response({:ok, responses}), do: {:ok, Enum.into(responses, %{}, &{&1.id, &1})}
  defp handle_batch_response({:error, {:bad_gateway, _request_url}}), do: {:error, :batch_error, "Bad gateway"}
  defp handle_batch_response({:error, {reason, _request_url}}), do: {:error, :batch_error, to_string(reason)}
  defp handle_batch_response({:error, reason}) when is_atom(reason), do: {:error, :batch_error, Atom.to_string(reason)}
  defp handle_batch_response({:error, error}), do: {:error, :batch_error, error}

  defp process_responses({:ok, response_map}, requests_with_index, parsed_abi, _requests, leave_error_as_map) do
    Enum.map(requests_with_index, fn {%{method_id: method_id}, index} ->
      process_single_response(response_map[index], index, method_id, parsed_abi, leave_error_as_map)
    end)
  end

  defp process_responses(
         {:error, :batch_error, error},
         _requests_with_index,
         _parsed_abi,
         requests,
         _leave_error_as_map
       ) do
    # Only apply error to all requests if the entire batch failed
    Enum.map(requests, fn _ -> format_error(error) end)
  end

  defp process_single_response(nil, _index, _method_id, _parsed_abi, _leave_error_as_map), do: {:error, "No result"}

  defp process_single_response({:local_error, message}, _index, _method_id, _parsed_abi, _leave_error_as_map),
    do: {:error, message}

  defp process_single_response(response, index, method_id, parsed_abi, leave_error_as_map) do
    selectors = define_selectors(parsed_abi, method_id)
    {^index, result} = Encoder.decode_result(response, selectors, leave_error_as_map)
    result
  rescue
    error ->
      format_error(error)
  end

  defp safe_format_args(function, args) do
    {:ok, format_args(function, args)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp safe_encode_function_call(function, formatted_args) do
    {:ok, Encoder.encode_function_call(function, formatted_args)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp safe_json_rpc(requests, json_rpc_named_arguments) do
    json_rpc(requests, json_rpc_named_arguments)
  rescue
    error -> {:error, error}
  catch
    :exit, reason -> {:error, reason}
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
    |> Enum.map(fn
      el when is_integer(el) ->
        el

      el ->
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

    params =
      %{to: contract_address, data: data}
      |> (&if(is_nil(from), do: &1, else: Map.put(&1, :from, from))).()

    full_params = %{
      id: id,
      method: "eth_call",
      params: [params, block]
    }

    request(full_params)
  end

  def eth_get_storage_at_request(contract_address, storage_pointer, id) do
    full_params = %{
      id: id,
      method: "eth_getStorageAt",
      params: [contract_address, storage_pointer, "latest"]
    }

    request(full_params)
  end

  defp format_error(nil), do: {:error, ""}

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
