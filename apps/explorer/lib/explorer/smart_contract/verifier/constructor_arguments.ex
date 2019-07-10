defmodule Explorer.SmartContract.Verifier.ConstructorArguments do
  @moduledoc """
  Smart contract contrstructor arguments verification logic.
  """

  alias Explorer.Chain

  def verify(address_hash, arguments_data) do
    arguments_data = arguments_data |> String.trim_trailing() |> String.trim_leading() |> String.replace("0x", "") |> IO.inspect

    address_hash
    |> Chain.contract_creation_input_data()
    |> String.replace("0x", "")
    |> extract_constructor_arguments(arguments_data)
  end

  defp extract_constructor_arguments(code, passed_constructor_arguments) do
    case code do
      "a165627a7a72305820" <> <<_::binary-size(64)>> <> "0029" <> constructor_arguments ->
        if passed_constructor_arguments == constructor_arguments do
          true
        else
          extract_constructor_arguments(constructor_arguments, passed_constructor_arguments)
        end

      "a265627a7a72305820" <>
          <<_::binary-size(64)>> <> "64736f6c6343" <> <<_::binary-size(6)>> <> "0032" <> constructor_arguments ->
        if passed_constructor_arguments == constructor_arguments do
          true
        else
          extract_constructor_arguments(constructor_arguments, passed_constructor_arguments)
        end

      <<>> ->
        passed_constructor_arguments == ""

      <<_::binary-size(2)>> <> rest ->
        extract_constructor_arguments(rest, passed_constructor_arguments)
    end
  end
end
