# credo:disable-for-this-file
defmodule Explorer.SmartContract.Verifier.ConstructorArguments do
  @moduledoc """
  Smart contract contrstructor arguments verification logic.
  """
  alias ABI.{FunctionSelector, TypeDecoder}
  alias Explorer.Chain

  require Logger

  Logger.configure(truncate: :infinity)

  def verify(address_hash, contract_code, arguments_data, contract_source_code, contract_name) do
    arguments_data = arguments_data |> String.trim_trailing() |> String.trim_leading("0x")

    creation_code =
      address_hash
      |> Chain.contract_creation_input_data()
      |> String.replace("0x", "")

    check_func = fn assumed_arguments -> assumed_arguments == arguments_data end

    extract_constructor_arguments(creation_code, check_func, contract_source_code, contract_name)
  end

  defp extract_constructor_arguments(code, check_func, contract_source_code, contract_name) do
    case code do

      <<>> ->
        # we should consdider change: use just :false
        check_func.("")

      <<_::binary-size(2)>> <> rest ->
        extract_constructor_arguments(rest, check_func, contract_source_code, contract_name)
    end
  end

  def find_constructor_arguments(creation_code, abi, contract_source_code, contract_name) do

    creation_code_new = creation_code |> String.slice(64..-1)

    Logger.warn(creation_code_new)

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
        _ ->
          false
      end
    end

    extract_constructor_arguments(creation_code_new, check_func, contract_source_code, contract_name)
  end

end
