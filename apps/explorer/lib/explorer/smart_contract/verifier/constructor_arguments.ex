defmodule Explorer.SmartContract.Verifier.ConstructorArguments do
  @moduledoc """
  Smart contract contrstructor arguments verification logic.
  """

  alias Explorer.Chain

  def verify(address_hash, contract_code, arguments_data) do
    arguments_data = arguments_data |> String.trim_trailing() |> String.trim_leading("0x")

    creation_code =
      address_hash
      |> Chain.contract_creation_input_data()
      |> String.replace("0x", "")

    if verify_older_version(creation_code, contract_code, arguments_data) do
      true
    else
      extract_constructor_arguments(creation_code, arguments_data)
    end
  end

  # Earlier versions of Solidity didn't have whisper code.
  # constructor argument were directly appended to source code
  defp verify_older_version(creation_code, contract_code, arguments_data) do
    creation_code
    |> String.split(contract_code)
    |> List.last()
    |> Kernel.==(arguments_data)
  end

  defp extract_constructor_arguments(code, passed_constructor_arguments) do
    case code do
      # Solidity ~ 4.23 # https://solidity.readthedocs.io/en/v0.4.23/metadata.html
      "a165627a7a72305820" <> <<_::binary-size(64)>> <> "0029" <> constructor_arguments ->
        if passed_constructor_arguments == constructor_arguments do
          true
        else
          extract_constructor_arguments(constructor_arguments, passed_constructor_arguments)
        end

      # Solidity >= 0.5.10 https://solidity.readthedocs.io/en/v0.5.10/metadata.html
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
