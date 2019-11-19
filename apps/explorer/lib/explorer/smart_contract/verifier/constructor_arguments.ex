defmodule Explorer.SmartContract.Verifier.ConstructorArguments do
  @moduledoc """
  Smart contract contrstructor arguments verification logic.
  """
  alias ABI.{FunctionSelector, TypeDecoder}
  alias Explorer.Chain

  def verify(address_hash, contract_code, arguments_data) do
    arguments_data = arguments_data |> String.trim_trailing() |> String.trim_leading("0x")

    creation_code =
      address_hash
      |> Chain.contract_creation_input_data()
      |> String.replace("0x", "")

    check_func = fn assumed_arguments -> assumed_arguments == arguments_data end

    if verify_older_version(creation_code, contract_code, check_func) do
      true
    else
      extract_constructor_arguments(creation_code, check_func)
    end
  end

  # Earlier versions of Solidity didn't have whisper code.
  # constructor argument were directly appended to source code
  defp verify_older_version(creation_code, contract_code, check_func) do
    creation_code
    |> String.split(contract_code)
    |> List.last()
    |> check_func.()
  end

  defp extract_constructor_arguments(code, check_func) do
    case code do
      # Solidity ~ 4.23 # https://solidity.readthedocs.io/en/v0.4.23/metadata.html
      "a165627a7a72305820" <> <<_::binary-size(64)>> <> "0029" <> constructor_arguments ->
        check_func_result = check_func.(constructor_arguments)

        if check_func_result do
          check_func_result
        else
          extract_constructor_arguments(constructor_arguments, check_func)
        end

      # Solidity >= 0.5.10 https://solidity.readthedocs.io/en/v0.5.10/metadata.html
      "a265627a7a72305820" <>
          <<_::binary-size(64)>> <> "64736f6c6343" <> <<_::binary-size(6)>> <> "0032" <> constructor_arguments ->
        check_func_result = check_func.(constructor_arguments)

        if check_func_result do
          check_func_result
        else
          extract_constructor_arguments(constructor_arguments, check_func)
        end

      # Solidity >= 0.5.11 https://github.com/ethereum/solidity/blob/develop/Changelog.md#0511-2019-08-12
      # Metadata: Update the swarm hash to the current specification, changes bzzr0 to bzzr1 and urls to use bzz-raw://
      "a265627a7a72315820" <>
          <<_::binary-size(64)>> <> "64736f6c6343" <> <<_::binary-size(6)>> <> "0032" <> constructor_arguments ->
        check_func_result = check_func.(constructor_arguments)

        if check_func_result do
          check_func_result
        else
          extract_constructor_arguments(constructor_arguments, check_func)
        end

      <<>> ->
        check_func.("")

      <<_::binary-size(2)>> <> rest ->
        extract_constructor_arguments(rest, check_func)
    end
  end

  def find_contructor_arguments(address_hash, abi) do
    creation_code =
      address_hash
      |> Chain.contract_creation_input_data()
      |> String.replace("0x", "")

    constructor_abi = Enum.find(abi, fn el -> el["type"] == "constructor" && el["inputs"] != [] end)

    input_types = Enum.map(constructor_abi["inputs"], &FunctionSelector.parse_specification_type/1)

    check_func = fn assumed_arguments ->
      try do
        _ =
          assumed_arguments
          |> Base.decode16!(case: :mixed)
          |> TypeDecoder.decode_raw(input_types)

        assumed_arguments
      rescue
        _ -> false
      end
    end

    extract_constructor_arguments(creation_code, check_func)
  end
end
