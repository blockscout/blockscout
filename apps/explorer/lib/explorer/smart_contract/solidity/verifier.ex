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
              source_code = map_json_input["sources"][file_path]["content"]
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
                    for {file, %{"content" => source}} <- map_json_input["sources"],
                        file != file_path,
                        do: %{"file_name" => file, "contract_source_code" => source, "address_hash" => address_hash}

                  additional_params =
                    map_json_input
                    |> extract_settings_from_json()
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
  
  defp debug(value, key) do
    require Logger
    Logger.configure(truncate: :infinity)
    Logger.debug(key)
    Logger.debug(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
    value
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

    solc_output =
      CodeCompiler.run(
        name: name,
        compiler_version: compiler_version,
        code: contract_source_code,
        optimize: optimization,
        optimization_runs: optimization_runs,
        evm_version: evm_version,
        external_libs: external_libraries
      ) |> debug("CodeCompiler")

    compare_bytecodes(
      solc_output,
      address_hash,
      constructor_arguments,
      autodetect_constructor_arguments,
      contract_source_code,
      name
    )|> debug("Compare bytecodes")
  end

  defp compare_bytecodes({:error, :name}, _, _, _, _, _), do: {:error, :name}
  defp compare_bytecodes({:error, _}, _, _, _, _, _), do: {:error, :compilation}

  defp compare_bytecodes({:error, _, error_message}, _, _, _, _, _) do
    {:error, :compilation, error_message}
  end

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
         uncasted_arguments_data,
         autodetect_constructor_arguments,
         _contract_source_code,
         _contract_name
       ) do
    arguments_data = cast_args_data(uncasted_arguments_data)

    %{
      "metadata_cbor_decoded" => _generated_metadata,
      "bytecode" => generated_bytecode,
      "compiler_version" => generated_compiler_version
    } = extract_bytecode_and_metadata_hash(bytecode) |> debug("extract_bytecode_and_metadata_hash bytecode" )

    blockchain_created_tx_input =
      case Chain.smart_contract_creation_tx_bytecode(address_hash) do
        %{init: init, created_contract_code: _created_contract_code} ->
          "0x" <> init_without_0x = init
          init_without_0x

        _ ->
          ""
      end |> debug("smart_contract_creation_tx_bytecode")

    constructor_args = extract_constructor_args(generated_compiler_version, blockchain_created_tx_input) |> debug("extract_constructor_args")

    blockchain_created_tx_input_without_constructor_args = if is_nil(constructor_args), do: blockchain_created_tx_input, else: String.trim_trailing(blockchain_created_tx_input, constructor_args)
      
    %{
      "metadata_cbor_decoded" => _metadata,
      "bytecode" => blockchain_bytecode_without_whisper,
      "compiler_version" => compiler_version_from_input
    } = extract_bytecode_and_metadata_hash(blockchain_created_tx_input_without_constructor_args) |> debug("extract_bytecode_and_metadata_hash blockchain_created_tx_input")

    empty_constructor_arguments = arguments_data == "" or arguments_data == nil

    cond do
      compiler_version_from_input != generated_compiler_version ->
        {:error, :compiler_version}

      bytecode <> arguments_data == blockchain_created_tx_input ->
        {:ok, %{abi: abi, constructor_arguments: arguments_data}}

      generated_bytecode != blockchain_bytecode_without_whisper &&
          !try_library_verification(generated_bytecode, blockchain_bytecode_without_whisper) ->
        {:error, :generated_bytecode}

      has_constructor_with_params?(abi) && autodetect_constructor_arguments && ConstructorArguments.check_constructor_args(constructor_args, abi) ->
        {:ok, %{abi: abi, constructor_arguments: constructor_args}}

      has_constructor_with_params?(abi) && empty_constructor_arguments ->
        {:error, :constructor_arguments}

      has_constructor_with_params?(abi) && ConstructorArguments.check_constructor_args(constructor_args, abi) && arguments_data == constructor_args ->
        {:ok, %{abi: abi, constructor_arguments: constructor_args}}
      
      has_constructor_with_params?(abi) && (arguments_data != constructor_args || !ConstructorArguments.check_constructor_args(constructor_args, abi)) ->
        {:error, :constructor_arguments}
    
      true ->
        {:ok, %{abi: abi}}
    end
  end

  defp cast_args_data("0x" <> args_data), do: cast_args_data(args_data)

  defp cast_args_data(args) when is_binary(args) do
    args |> String.trim() |> String.downcase()
  end

  defp cast_args_data(args), do: args

  defp extract_constructor_args(compiler_version, created_tx_input) when is_binary(compiler_version) and is_binary(created_tx_input) and compiler_version != "" and created_tx_input != "" do
    with assumed_args <- created_tx_input |> String.split(Base.encode16(compiler_version , case: :lower)) |> List.last(),
         false <- is_nil(assumed_args),
         false <- assumed_args == "",
         <<_metadata_length::binary-size(4)>> <> args <- assumed_args do
          args
    else
      _ ->
        nil
    end
  end

  defp extract_constructor_args(_, _), do: nil

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
    %{"metadata_cbor_decoded" => nil, "bytecode" => nil, "compiler_version" => nil}
  end

  def extract_bytecode_and_metadata_hash("0x" <> code) do
    %{"metadata_cbor_decoded" => metadata_cbor_decoded, "bytecode" => bytecode, "compiler_version" => compiler_version} =
      extract_bytecode_and_metadata_hash(code)

    %{"metadata_cbor_decoded" => metadata_cbor_decoded, "bytecode" => "0x" <> bytecode, "compiler_version" => compiler_version}
  end

  # changes inspired by https://github.com/blockscout/blockscout/issues/5430
  def extract_bytecode_and_metadata_hash(code) do
    with {meta_length, ""} <- code |> String.slice(-4..-1) |> Integer.parse(16),
          meta <- String.slice(code, -(meta_length + 2) * 2 .. -5),
          {:ok, meta_raw_binary} <- Base.decode16(meta, case: :lower),
          {:ok, decoded_meta, _remain} <- CBOR.decode(meta_raw_binary),
          bytecode <- String.slice(code, -String.length(code) .. -(meta_length + 2) * 2 - 1),
          false <- bytecode == "" do
      %{"metadata_cbor_decoded" => decoded_meta, "bytecode" => bytecode, "compiler_version" => decoded_meta["solc"]}
    else
      _ ->
        %{"metadata_cbor_decoded" => nil, "bytecode" => code, "compiler_version" => nil}
    end
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

  defp parse_boolean(true), do: true
  defp parse_boolean(false), do: false
end
