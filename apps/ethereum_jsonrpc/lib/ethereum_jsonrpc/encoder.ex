defmodule EthereumJSONRPC.Encoder do
  @moduledoc """
  Deals with encoding and decoding data to be sent to, or that is
  received from, the blockchain.
  """

  alias ABI.TypeDecoder

  @doc """
  Given an ABI and a set of functions, returns the data the blockchain expects.
  """
  @spec encode_abi([map()], %{String.t() => [any()]}) :: map()
  def encode_abi(abi, functions) do
    abi
    |> ABI.parse_specification()
    |> get_selectors(functions)
    |> Enum.map(&encode_function_call/1)
    |> Map.new()
  end

  @doc """
  Given a list of function selectors from the ABI lib, and a list of functions names with their arguments, returns a list of selectors with their functions.
  """
  @spec get_selectors([%ABI.FunctionSelector{}], %{String.t() => [term()]}) :: [{%ABI.FunctionSelector{}, [term()]}]
  def get_selectors(abi, functions) do
    Enum.map(functions, fn {function_name, args} ->
      {get_selector_from_name(abi, function_name), args}
    end)
  end

  @doc """
  Given a list of function selectors from the ABI lib, and a function name, get the selector for that function.
  """
  @spec get_selector_from_name([%ABI.FunctionSelector{}], String.t()) :: %ABI.FunctionSelector{}
  def get_selector_from_name(abi, function_name) do
    Enum.find(abi, fn selector -> function_name == selector.function end)
  end

  @doc """
  Given a function selector and a list of arguments, returns their econded versions.

  This is what is expected on the Json RPC data parameter.
  """
  @spec encode_function_call({%ABI.FunctionSelector{}, [term()]}) :: {String.t(), String.t()}
  def encode_function_call({function_selector, args}) do
    encoded_args =
      function_selector
      |> ABI.encode(args)
      |> Base.encode16(case: :lower)

    {function_selector.function, "0x" <> encoded_args}
  end

  @doc """
  Given a result set from the blockchain, and the functions selectors, returns the results decoded.

  This functions assumes the result["id"] is the name of the function the result is for.
  """
  @spec decode_abi_results({any(), [map()]}, [map()], %{String.t() => [any()]}) :: map()
  def decode_abi_results({:ok, results}, abi, functions) do
    selectors =
      abi
      |> ABI.parse_specification()
      |> get_selectors(functions)
      |> Enum.map(fn {selector, _args} -> selector end)

    results
    |> Stream.map(&join_result_and_selector(&1, selectors))
    |> Stream.map(&decode_result/1)
    |> Map.new()
  end

  defp join_result_and_selector(result, selectors) do
    {result, Enum.find(selectors, &(&1.function == result["id"]))}
  end

  @doc """
  Given a result from the blockchain, and the function selector, returns the result decoded.
  """
  @spec decode_result({map(), %ABI.FunctionSelector{}}) :: {String.t(), [String.t()]}
  def decode_result({%{"error" => %{"code" => code, "message" => message}, "id" => id}, _selector}) do
    {id, ["#{code} => #{message}"]}
  end

  def decode_result({%{"id" => id, "result" => result}, function_selector}) do
    decoded_result =
      result
      |> String.slice(2..-1)
      |> Base.decode16!(case: :lower)
      |> TypeDecoder.decode_raw(List.wrap(function_selector.returns))

    {id, decoded_result}
  end
end
