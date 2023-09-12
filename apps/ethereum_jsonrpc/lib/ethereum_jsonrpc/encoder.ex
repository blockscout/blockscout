defmodule EthereumJSONRPC.Encoder do
  @moduledoc """
  Deals with encoding and decoding data to be sent to, or that is
  received from, the blockchain.
  """

  alias ABI.TypeDecoder

  @doc """
  Given a function selector and a list of arguments, returns their encoded versions.

  This is what is expected on the Json RPC data parameter.
  """
  @spec encode_function_call(ABI.FunctionSelector.t(), [term()]) :: String.t()
  def encode_function_call(function_selector, args) when is_list(args) do
    parsed_args = parse_args(args)

    encoded_args =
      function_selector
      |> ABI.encode(parsed_args)
      |> Base.encode16(case: :lower)

    "0x" <> encoded_args
  end

  def encode_function_call(function_selector, args), do: encode_function_call(function_selector, [args])

  defp parse_args(args) when is_list(args) do
    args
    |> Enum.map(&parse_args/1)
  end

  defp parse_args(<<"0x", hexadecimal_digits::binary>>), do: Base.decode16!(hexadecimal_digits, case: :mixed)

  defp parse_args(<<hexadecimal_digits::binary>>), do: try_to_decode(hexadecimal_digits)

  defp parse_args(arg), do: arg

  defp try_to_decode(hexadecimal_digits) do
    case Base.decode16(hexadecimal_digits, case: :mixed) do
      {:ok, decoded_value} ->
        decoded_value

      _ ->
        hexadecimal_digits
    end
  end

  @doc """
  Given a result from the blockchain, and the function selector, returns the result decoded.
  """
  def decode_result(_, _, leave_error_as_map \\ false)

  @spec decode_result(map(), ABI.FunctionSelector.t() | [ABI.FunctionSelector.t()]) ::
          {String.t(), {:ok, any()} | {:error, String.t() | :invalid_data}}
  def decode_result(%{error: %{code: code, data: data, message: message}, id: id}, _selector, leave_error_as_map) do
    if leave_error_as_map do
      {id, {:error, %{code: code, message: message, data: data}}}
    else
      {id, {:error, "(#{code}) #{message} (#{data})"}}
    end
  end

  def decode_result(%{error: %{code: code, message: message}, id: id}, _selector, leave_error_as_map) do
    if leave_error_as_map do
      {id, {:error, %{code: code, message: message}}}
    else
      {id, {:error, "(#{code}) #{message}"}}
    end
  end

  def decode_result(%{id: id, result: _result} = result, selectors, _leave_error_as_map) when is_list(selectors) do
    selectors
    |> Enum.map(fn selector ->
      try do
        decode_result(result, selector)
      rescue
        _ -> :error
      end
    end)
    |> Enum.find({id, {:error, :unable_to_decode}}, fn decode ->
      case decode do
        {_id, {:ok, _}} -> true
        _ -> false
      end
    end)
  end

  def decode_result(%{id: id, result: result}, function_selector, _leave_error_as_map) do
    types_list = List.wrap(function_selector.returns)

    decoded_data =
      result
      |> String.slice(2..-1)
      |> Base.decode16!(case: :lower)
      |> TypeDecoder.decode_raw(types_list)
      |> Enum.zip(types_list)
      |> Enum.map(fn
        {value, :address} -> "0x" <> Base.encode16(value, case: :lower)
        {value, :string} -> unescape(value)
        {value, _} -> value
      end)

    {id, {:ok, decoded_data}}
  rescue
    MatchError ->
      {id, {:error, :invalid_data}}
  end

  def unescape(data) do
    if String.starts_with?(data, "\\x") do
      charlist = String.to_charlist(data)
      erlang_literal = '"#{charlist}"'
      {:ok, [{:string, _, unescaped_charlist}], _} = :erl_scan.string(erlang_literal)
      List.to_string(unescaped_charlist)
    else
      data
    end
  end
end
