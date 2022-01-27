# credo:disable-for-this-file
defmodule Explorer.SmartContract.Solidity.Verifier do
  @moduledoc """
  Module responsible to verify the Smart Contract.

  Given a contract source code the bytecode will be generated  and matched
  against the existing Creation Address Bytecode, if it matches the contract is
  then Verified.
  """

  alias Explorer.Chain
  alias Explorer.SmartContract.Solidity.CodeCompiler
  alias Explorer.SmartContract.Verifier.ConstructorArguments

  # @metadata_hash_prefix_0_4_23 "a165627a7a72305820"
  # @metadata_hash_prefix_0_5_family_1 "65627a7a723"
  # @metadata_hash_prefix_0_5_family_2 "5820"
  # @metadata_hash_prefix_0_6_0 "a264697066735822"

  # @experimental "6c6578706572696d656e74616cf5"
  # @metadata_hash_common_suffix "64736f6c63"

  def evaluate_authenticity(_, %{"name" => ""}), do: {:error, :name}

  def evaluate_authenticity(_, %{"contract_source_code" => ""}),
    do: {:error, :contract_source_code}

  def evaluate_authenticity(address_hash, params) do
    verify(address_hash, params)
  end

  def evaluate_authenticity_via_standard_json_input(address_hash, params, json_input) do
    verify(address_hash, params, json_input)
  end

  defp verify(address_hash, params, json_input) do
    name = Map.get(params, "name", "")

    compiler_version = Map.fetch!(params, "compiler_version")
    constructor_arguments = Map.get(params, "constructor_arguments", "")
    autodetect_constructor_arguments = params |> Map.get("autodetect_constructor_args", "false") |> parse_boolean()



    solc_output =
      CodeCompiler.run(
        [
          name: name,
          compiler_version: compiler_version
        ],
        json_input
      )

    case solc_output do
      {:ok, candidates} ->
        case Jason.decode(json_input) do
          {:ok, map_json_input} ->
            Enum.reduce_while(candidates, %{}, fn candidate, _acc ->
              file_path = candidate["file_path"]
              source_code = map_json_input["input"]["sources"][file_path]["content"]
              contract_name = candidate["name"]

              case compare_bytecodes(
                     candidate,
                     address_hash,
                     constructor_arguments,
                     autodetect_constructor_arguments,
                     source_code,
                     contract_name
                   ) do
                {:ok, verified_data} ->
                  secondary_sources =
                    for {file, %{"content" => source}} <- map_json_input["input"]["sources"],
                        file != file_path,
                        do: %{"file_name" => file, "contract_source_code" => source, "address_hash" => address_hash}

                  additional_params =
                    map_json_input["input"]
                    |> Map.put("optimization", true)
                    |> Map.put("optimization_runs", 200)
                    |> Map.put("contract_source_code", source_code)
                    |> Map.put("file_path", file_path)
                    |> Map.put("name", contract_name)
                    |> Map.put("secondary_sources", secondary_sources)

                  {:halt, {:ok, verified_data, additional_params}}

                err ->
                  {:cont, {:error, err}}
              end
            end)

          _ ->
            {:error, :json}
        end

      error_response ->
        error_response
    end

  end

  defp extract_settings_from_json(json_input) when is_map(json_input) do
    %{"enabled" => optimization, "runs" => optimization_runs} = json_input["settings"]["optimizer"]

    %{"optimization" => optimization}
    |> (&if(parse_boolean(optimization), do: Map.put(&1, "optimization_runs", optimization_runs), else: &1)).()
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
    autodetect_constructor_arguments = params |> Map.get("autodetect_constructor_args", "false") |> parse_boolean()

    solc_output = CodeCompiler.run(
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
      autodetect_constructor_arguments,
      contract_source_code,
      name
    )
  end

  defp compare_bytecodes({:error, :name}, _, _, _, _, _), do: {:error, :name}
  defp compare_bytecodes({:error, _}, _, _, _, _, _), do: {:error, :compilation}

  defp compare_bytecodes({:error, _, error_message}, _, _, _, _, _) do
    {:error, :compilation, error_message}
  end

  defp compare_bytecodes(
    %{"abi" => abi, "bytecode" => bytecode, "file_path" => _file_path, "name" => _name},
    address_hash,
    arguments_data,
    autodetect_constructor_arguments,
    contract_source_code,
    contract_name
  ),
  do:
    compare_bytecodes(
      {:ok, %{"abi" => abi, "bytecode" => bytecode}},
      address_hash,
      arguments_data,
      autodetect_constructor_arguments,
      contract_source_code,
      contract_name
    )

  defp compare_bytecodes(
    %{"abi" => abi, "bytecode" => bytecode},
    address_hash,
    arguments_data,
    autodetect_constructor_arguments,
    contract_source_code,
    contract_name
  ),
  do:
    compare_bytecodes(
      {:ok, %{"abi" => abi, "bytecode" => bytecode}},
      address_hash,
      arguments_data,
      autodetect_constructor_arguments,
      contract_source_code,
      contract_name
    )

  # credo:disable-for-next-line /Complexity/
  defp compare_bytecodes(
         {:ok, %{"abi" => abi, "bytecode" => bytecode}},
         address_hash,
         arguments_data,
         _autodetect_constructor_arguments,
         _contract_source_code,
         _contract_name
       ) do
    %{
      "metadata_hash" => _generated_metadata_hash,
      "bytecode" => generated_bytecode,
      "compiler_version" => _generated_compiler_version
    } = extract_bytecode_and_metadata_hash(bytecode)

    # generated_bytecode = solc_output from compile_solc

    # blockchain_bytecode_without_whisper = blockchain_created_tx_input from local db

    blockchain_created_tx_input =
      case Chain.smart_contract_creation_tx_bytecode(address_hash) do
        %{init: init, created_contract_code: _created_contract_code} ->
          "0x70" <> init_without_0x = init
          init_without_0x

        _ ->
          bytecode
      end

    %{
      "data" => _constructor_data,
      "factoryDeps" => blockchain_bytecode_without_whisper,
    } = deserialize_creation_tx(blockchain_created_tx_input)

    empty_constructor_arguments = arguments_data == "" or arguments_data == nil

    cond do
      generated_bytecode != blockchain_bytecode_without_whisper ->
        {:error, :generated_bytecode}

      true ->
        {:ok, %{abi: abi}}
    end
  end

  def to_hex(bin), do: Base.encode16(bin, case: :lower)

  defp deserialize_creation_tx(calldata) do
    raw = calldata |> ExRLP.decode(encoding: :hex)
    data = Enum.at(raw, 5) |> to_hex()
    factoryDeps = Enum.at(Enum.at(raw, 15), 0) |> to_hex()
    %{"data" => data, "factoryDeps" => factoryDeps}
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
  def extract_bytecode_and_metadata_hash(nil) do
    %{"metadata_hash" => nil, "bytecode" => nil, "compiler_version" => nil}
  end

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

  defp has_constructor_with_params?(abi) do
    Enum.any?(abi, fn el -> el["type"] == "constructor" && el["inputs"] != [] end)
  end

  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
end
