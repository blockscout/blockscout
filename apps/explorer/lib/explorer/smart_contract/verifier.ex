# credo:disable-for-this-file
defmodule Explorer.SmartContract.Verifier do
  @moduledoc """
  Module responsible to verify the Smart Contract.

  Given a contract source code the bytecode will be generated  and matched
  against the existing Creation Address Bytecode, if it matches the contract is
  then Verified.
  """

  alias Explorer.Chain
  alias Explorer.SmartContract.Solidity.CodeCompiler
  alias Explorer.SmartContract.Verifier.ConstructorArguments

  @metadata_hash_prefix_0_4_23 "a165627a7a72305820"
  @metadata_hash_prefix_0_5_family_1 "65627a7a723"
  @metadata_hash_prefix_0_5_family_2 "5820"
  @metadata_hash_prefix_0_6_0 "a264697066735822"

  @experimental "6c6578706572696d656e74616cf5"
  @metadata_hash_common_suffix "64736f6c63"

  def evaluate_authenticity(_, %{"name" => ""}), do: {:error, :name}

  def evaluate_authenticity(_, %{"contract_source_code" => ""}),
    do: {:error, :contract_source_code}

  def evaluate_authenticity(address_hash, params) do
    latest_evm_version = List.last(CodeCompiler.allowed_evm_versions())
    evm_version = Map.get(params, "evm_version", latest_evm_version)

    all_versions = [evm_version | previous_evm_versions(evm_version)]

    all_versions_extra = all_versions ++ [evm_version]

    Enum.reduce_while(all_versions_extra, false, fn version, acc ->
      case acc do
        {:ok, _} = result ->
          {:cont, result}

        {:error, :compiler_version} ->
          {:halt, acc}

        {:error, :name} ->
          {:halt, acc}

        _ ->
          cur_params = Map.put(params, "evm_version", version)
          {:cont, verify(address_hash, cur_params)}
      end
    end)
  end

  defp verify(address_hash, params) do
    name = Map.fetch!(params, "name")
    contract_source_code = Map.fetch!(params, "contract_source_code")
    optimization = Map.fetch!(params, "optimization")
    compiler_version = Map.fetch!(params, "compiler_version")
    external_libraries = Map.get(params, "external_libraries", %{})
    constructor_arguments = Map.get(params, "constructor_arguments", "")
    evm_version = Map.get(params, "evm_version")
    optimization_runs = Map.get(params, "optimization_runs", 200)
    autodetect_contructor_arguments = params |> Map.get("autodetect_contructor_args", "false") |> parse_boolean()

    solc_output =
      CodeCompiler.run(
        name: name,
        compiler_version: compiler_version,
        code: contract_source_code,
        optimize: optimization,
        optimization_runs: optimization_runs,
        evm_version: evm_version,
        external_libs: external_libraries
      )

    compare_bytecodes(
      solc_output,
      address_hash,
      constructor_arguments,
      autodetect_contructor_arguments,
      contract_source_code,
      name
    )
  end

  defp compare_bytecodes({:error, :name}, _, _, _, _, _), do: {:error, :name}
  defp compare_bytecodes({:error, _}, _, _, _, _, _), do: {:error, :compilation}

  defp compare_bytecodes({:error, _, error_message}, _, _, _, _, _) do
    {:error, :compilation, error_message}
  end

  # credo:disable-for-next-line /Complexity/
  defp compare_bytecodes(
         {:ok, %{"abi" => abi, "bytecode" => bytecode}},
         address_hash,
         arguments_data,
         autodetect_contructor_arguments,
         contract_source_code,
         contract_name
       ) do
    %{
      "metadata_hash" => _generated_metadata_hash,
      "bytecode" => generated_bytecode,
      "compiler_version" => generated_compiler_version
    } = extract_bytecode_and_metadata_hash(bytecode)

    blockchain_created_tx_input =
      case Chain.smart_contract_creation_tx_bytecode(address_hash) do
        nil ->
          bytecode

        blockchain_created_tx_input_with_0x ->
          "0x" <> blockchain_created_tx_input = blockchain_created_tx_input_with_0x
          blockchain_created_tx_input
      end

    %{
      "metadata_hash" => _metadata_hash,
      "bytecode" => blockchain_bytecode_without_whisper,
      "compiler_version" => compiler_version_from_input
    } = extract_bytecode_and_metadata_hash(blockchain_created_tx_input)

    empty_constructor_arguments = arguments_data == "" or arguments_data == nil

    cond do
      compiler_version_from_input != generated_compiler_version ->
        {:error, :compiler_version}

      generated_bytecode != blockchain_bytecode_without_whisper &&
          !try_library_verification(generated_bytecode, blockchain_bytecode_without_whisper) ->
        {:error, :generated_bytecode}

      has_constructor_with_params?(abi) && autodetect_contructor_arguments ->
        result = ConstructorArguments.find_constructor_arguments(address_hash, abi, contract_source_code, contract_name)

        if result do
          {:ok, %{abi: abi, contructor_arguments: result}}
        else
          {:error, :constructor_arguments}
        end

      has_constructor_with_params?(abi) && empty_constructor_arguments ->
        {:error, :constructor_arguments}

      has_constructor_with_params?(abi) &&
          !ConstructorArguments.verify(
            address_hash,
            blockchain_bytecode_without_whisper,
            arguments_data,
            contract_source_code,
            contract_name
          ) ->
        {:error, :constructor_arguments}

      true ->
        {:ok, %{abi: abi}}
    end
  end

  # 730000000000000000000000000000000000000000 - default library address that returned by the compiler
  defp try_library_verification(
         "730000000000000000000000000000000000000000" <> bytecode,
         <<_address::binary-size(42)>> <> bytecode
       ) do
    true
  end

  defp try_library_verification(_, _) do
    false
  end

  @doc """
  In order to discover the bytecode we need to remove the `swarm source` from
  the hash.

  For more information on the swarm hash, check out:
  https://solidity.readthedocs.io/en/v0.5.3/metadata.html#encoding-of-the-metadata-hash-in-the-bytecode
  """
  def extract_bytecode_and_metadata_hash("0x" <> code) do
    %{"metadata_hash" => metadata_hash, "bytecode" => bytecode, "compiler_version" => compiler_version} =
      extract_bytecode_and_metadata_hash(code)

    %{"metadata_hash" => metadata_hash, "bytecode" => "0x" <> bytecode, "compiler_version" => compiler_version}
  end

  def extract_bytecode_and_metadata_hash(code) do
    do_extract_bytecode_and_metadata_hash([], String.downcase(code), nil, nil)
  end

  defp do_extract_bytecode_and_metadata_hash(extracted, remaining, metadata_hash, compiler_version) do
    case remaining do
      <<>> ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      @metadata_hash_prefix_0_4_23 <> <<metadata_hash::binary-size(64)>> <> "0029" <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      # Solidity >= 0.5 family && experimantal
      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<metadata_hash::binary-size(64)>> <>
          @experimental <>
          @metadata_hash_common_suffix <>
          "43" <> <<compiler_version::binary-size(6)>> <> <<_::binary-size(4)>> <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<metadata_hash::binary-size(64)>> <>
          @experimental <>
          <<_::binary-size(4)>> <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      # Solidity >= 0.5.9; https://github.com/ethereum/solidity/blob/aa4ee3a1559ebc0354926af962efb3fcc7dc15bd/docs/metadata.rst
      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<metadata_hash::binary-size(64)>> <>
          @metadata_hash_common_suffix <>
          "43" <> <<compiler_version::binary-size(6)>> <> "0032" <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<metadata_hash::binary-size(64)>> <>
          @metadata_hash_common_suffix <>
          "78" <>
          <<_::binary-size(2)>> <>
          <<compiler_version::binary-size(76)>> <> "00" <> <<_::binary-size(2)>> <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<metadata_hash::binary-size(64)>> <>
          @metadata_hash_common_suffix <>
          "78" <>
          <<_::binary-size(2)>> <>
          <<compiler_version::binary-size(78)>> <> "00" <> <<_::binary-size(2)>> <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<metadata_hash::binary-size(64)>> <>
          @metadata_hash_common_suffix <>
          "78" <>
          <<_::binary-size(2)>> <>
          <<compiler_version::binary-size(80)>> <> "00" <> <<_::binary-size(2)>> <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<metadata_hash::binary-size(64)>> <>
          @metadata_hash_common_suffix <>
          "78" <>
          <<_::binary-size(2)>> <>
          <<compiler_version::binary-size(82)>> <> "00" <> <<_::binary-size(2)>> <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      # Solidity >= 0.6.0 https://github.com/ethereum/solidity/blob/develop/Changelog.md#060-2019-12-17
      # https://github.com/ethereum/solidity/blob/26b700771e9cc9c956f0503a05de69a1be427963/docs/metadata.rst#encoding-of-the-metadata-hash-in-the-bytecode
      # IPFS is used instead of Swarm
      # The current version of the Solidity compiler usually adds the following to the end of the deployed bytecode:
      # 0xa2
      # 0x64 'i' 'p' 'f' 's' 0x58 0x22 <34 bytes IPFS hash>
      # 0x64 's' 'o' 'l' 'c' 0x43 <3 byte version encoding>
      # 0x00 0x32
      # Note: there is a bug in the docs. Instead of 0x32, 0x33 should be used.
      # Fixing PR has been created https://github.com/ethereum/solidity/pull/8174
      @metadata_hash_prefix_0_6_0 <>
          <<metadata_hash::binary-size(68)>> <>
          @metadata_hash_common_suffix <>
          "43" <> <<compiler_version::binary-size(6)>> <> "0033" <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      @metadata_hash_prefix_0_6_0 <>
          <<metadata_hash::binary-size(68)>> <>
          @metadata_hash_common_suffix <>
          "78" <>
          <<_::binary-size(2)>> <>
          <<compiler_version::binary-size(76)>> <> "00" <> <<_::binary-size(2)>> <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      @metadata_hash_prefix_0_6_0 <>
          <<metadata_hash::binary-size(68)>> <>
          @metadata_hash_common_suffix <>
          "78" <>
          <<_::binary-size(2)>> <>
          <<compiler_version::binary-size(78)>> <> "00" <> <<_::binary-size(2)>> <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      @metadata_hash_prefix_0_6_0 <>
          <<metadata_hash::binary-size(68)>> <>
          @metadata_hash_common_suffix <>
          "78" <>
          <<_::binary-size(2)>> <>
          <<compiler_version::binary-size(80)>> <> "00" <> <<_::binary-size(2)>> <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      @metadata_hash_prefix_0_6_0 <>
          <<metadata_hash::binary-size(68)>> <>
          @metadata_hash_common_suffix <>
          "78" <>
          <<_::binary-size(2)>> <>
          <<compiler_version::binary-size(82)>> <> "00" <> <<_::binary-size(2)>> <> _constructor_arguments ->
        do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version)

      <<next::binary-size(2)>> <> rest ->
        do_extract_bytecode_and_metadata_hash([next | extracted], rest, metadata_hash, compiler_version)
    end
  end

  defp do_extract_bytecode_and_metadata_hash_output(metadata_hash, extracted, compiler_version) do
    bytecode =
      extracted
      |> Enum.reverse()
      |> :binary.list_to_bin()

    %{"metadata_hash" => metadata_hash, "bytecode" => bytecode, "compiler_version" => compiler_version}
  end

  def previous_evm_versions(current_evm_version) do
    index = Enum.find_index(CodeCompiler.allowed_evm_versions(), fn el -> el == current_evm_version end)

    cond do
      index == 0 ->
        []

      index == 1 ->
        [List.first(CodeCompiler.allowed_evm_versions())]

      true ->
        [
          Enum.at(CodeCompiler.allowed_evm_versions(), index - 1),
          Enum.at(CodeCompiler.allowed_evm_versions(), index - 2)
        ]
    end
  end

  defp has_constructor_with_params?(abi) do
    Enum.any?(abi, fn el -> el["type"] == "constructor" && el["inputs"] != [] end)
  end

  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
end
