defmodule Explorer.SmartContract.Solidity.Publisher do
  @moduledoc """
  Module responsible to control the contract verification.
  """

  require Logger

  import Explorer.SmartContract.Helper, only: [cast_libraries: 1, prepare_license_type: 1]

  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.{CompilerVersion, Helper}
  alias Explorer.SmartContract.Solidity.Verifier

  @sc_verification_via_flattened_file_started "Smart-contract verification via flattened file started"
  @sc_verification_via_standard_json_input_started "Smart-contract verification via standard json input started"
  @sc_verification_via_multipart_files_started "Smart-contract verification via multipart files started"

  @doc """
  Evaluates smart contract authenticity and saves its details.

  ## Examples
      Explorer.SmartContract.Solidity.Publisher.publish(
        "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
        %{
          "compiler_version" => "0.4.24",
          "contract_source_code" => "pragma solidity ^0.4.24; contract SimpleStorage { uint storedData; function set(uint x) public { storedData = x; } function get() public constant returns (uint) { return storedData; } }",
          "name" => "SimpleStorage",
          "optimization" => false
        }
      )
      #=> {:ok, %Explorer.Chain.SmartContract{}}

  """
  def publish(address_hash, params, external_libraries \\ %{}) do
    Logger.info(@sc_verification_via_flattened_file_started)
    params_with_external_libraries = add_external_libraries(params, external_libraries)

    case Verifier.evaluate_authenticity(address_hash, params_with_external_libraries) do
      {
        :ok,
        %{
          "abi" => _,
          "compilerVersion" => _,
          "constructorArguments" => _,
          "contractName" => _,
          "fileName" => _,
          "compilerSettings" => _,
          "sourceFiles" => _
        } = result_params
      } ->
        process_rust_verifier_response(result_params, address_hash, params, false, false)

      {:ok, %{abi: abi, constructor_arguments: constructor_arguments}} ->
        params_with_constructor_arguments =
          Map.put(params_with_external_libraries, "constructor_arguments", constructor_arguments)

        publish_smart_contract(address_hash, params_with_constructor_arguments, abi, false)

      {:ok, %{abi: abi}} ->
        publish_smart_contract(address_hash, params_with_external_libraries, abi, false)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params_with_external_libraries, error, nil)}

      {:error, error, error_message} ->
        {:error, unverified_smart_contract(address_hash, params_with_external_libraries, error, error_message)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params_with_external_libraries, "Unexpected error", nil)}
    end
  end

  def publish_with_standard_json_input(%{"address_hash" => address_hash} = params, json_input) do
    Logger.info(@sc_verification_via_standard_json_input_started)
    params = maybe_add_zksync_specific_data(params)

    case Verifier.evaluate_authenticity_via_standard_json_input(address_hash, params, json_input) do
      {:ok,
       %{
         "abi" => _,
         "compilerVersion" => _,
         "constructorArguments" => _,
         "contractName" => _,
         "fileName" => _,
         "sourceFiles" => _,
         "compilerSettings" => _
       } = result_params} ->
        process_rust_verifier_response(result_params, address_hash, params, true, true)

      # zksync
      {:ok,
       %{
         "compilationArtifacts" => compilation_artifacts_string,
         "evmCompiler" => _,
         "zkCompiler" => _,
         "contractName" => _,
         "fileName" => _,
         "sources" => _,
         "compilerSettings" => _,
         "runtimeMatch" => _
       } = result_params} ->
        compilation_artifacts = Jason.decode!(compilation_artifacts_string)

        transformed_result_params =
          result_params
          |> Map.put("abi", Map.get(compilation_artifacts, "abi"))

        process_rust_verifier_response(transformed_result_params, address_hash, params, true, true)

      {:ok, %{abi: abi, constructor_arguments: constructor_arguments}, additional_params} ->
        params_with_constructor_arguments =
          params
          |> Map.put("constructor_arguments", constructor_arguments)
          |> Map.merge(additional_params)

        publish_smart_contract(address_hash, params_with_constructor_arguments, abi, true)

      {:ok, %{abi: abi}, additional_params} ->
        merged_params = Map.merge(params, additional_params)
        publish_smart_contract(address_hash, merged_params, abi, true)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params, error, nil, true)}

      {:error, error, error_message} ->
        {:error, unverified_smart_contract(address_hash, params, error, error_message, true)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params, "Failed to verify", nil, true)}
    end
  end

  def publish_with_multi_part_files(%{"address_hash" => address_hash} = params, external_libraries \\ %{}, files) do
    Logger.info(@sc_verification_via_multipart_files_started)
    params_with_external_libraries = add_external_libraries(params, external_libraries)

    case Verifier.evaluate_authenticity_via_multi_part_files(address_hash, params_with_external_libraries, files) do
      {:ok,
       %{
         "abi" => _,
         "compilerVersion" => _,
         "constructorArguments" => _,
         "contractName" => _,
         "fileName" => _,
         "sourceFiles" => _,
         "compilerSettings" => _
       } = result_params} ->
        process_rust_verifier_response(result_params, address_hash, params, false, true)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params, error, nil, true)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params, "Failed to verify", nil, true)}
    end
  end

  def process_rust_verifier_response(
        source,
        address_hash,
        initial_params,
        is_standard_json?,
        save_file_path?,
        automatically_verified? \\ false
      )

  # zksync
  def process_rust_verifier_response(
        %{
          "abi" => abi,
          "evmCompiler" => %{"version" => compiler_version},
          "contractName" => contract_name,
          "fileName" => file_name,
          "sources" => sources,
          "compilerSettings" => compiler_settings_string,
          "runtimeMatch" => %{"type" => match_type},
          "zkCompiler" => %{"version" => zk_compiler_version}
        },
        address_hash,
        initial_params,
        is_standard_json?,
        save_file_path?,
        _automatically_verified?
      ) do
    secondary_sources =
      for {file, source} <- sources,
          file != file_name,
          do: %{"file_name" => file, "contract_source_code" => source, "address_hash" => address_hash}

    %{^file_name => contract_source_code} = sources

    compiler_settings = Jason.decode!(compiler_settings_string)

    optimization = extract_optimization(compiler_settings)

    optimization_runs = zksync_parse_optimization_runs(compiler_settings, optimization)

    constructor_arguments =
      if initial_params["constructor_arguments"] !== "0x", do: initial_params["constructor_arguments"], else: nil

    prepared_params =
      %{}
      |> Map.put("optimization", optimization)
      |> Map.put("optimization_runs", optimization_runs)
      |> Map.put("evm_version", compiler_settings["evmVersion"] || "default")
      |> Map.put("compiler_version", compiler_version)
      |> Map.put("zk_compiler_version", zk_compiler_version)
      |> Map.put("constructor_arguments", constructor_arguments)
      |> Map.put("contract_source_code", contract_source_code)
      |> Map.put("external_libraries", cast_libraries(compiler_settings["libraries"] || %{}))
      |> Map.put("name", contract_name)
      |> Map.put("file_path", if(save_file_path?, do: file_name))
      |> Map.put("secondary_sources", secondary_sources)
      |> Map.put("compiler_settings", if(is_standard_json?, do: compiler_settings))
      |> Map.put("partially_verified", match_type == "PARTIAL")
      |> Map.put("verified_via_sourcify", false)
      |> Map.put("verified_via_eth_bytecode_db", false)
      |> Map.put("verified_via_verifier_alliance", false)
      |> Map.put("license_type", initial_params["license_type"])
      |> Map.put("is_blueprint", false)

    publish_smart_contract(address_hash, prepared_params, abi, save_file_path?)
  end

  def process_rust_verifier_response(
        %{
          "abi" => abi_string,
          "compilerVersion" => compiler_version,
          "constructorArguments" => constructor_arguments,
          "contractName" => contract_name,
          "fileName" => file_name,
          "sourceFiles" => sources,
          "compilerSettings" => compiler_settings_string,
          "matchType" => match_type
        } = source,
        address_hash,
        initial_params,
        is_standard_json?,
        save_file_path?,
        automatically_verified?
      ) do
    secondary_sources =
      for {file, source} <- sources,
          file != file_name,
          do: %{"file_name" => file, "contract_source_code" => source, "address_hash" => address_hash}

    %{^file_name => contract_source_code} = sources

    compiler_settings = Jason.decode!(compiler_settings_string)

    optimization = extract_optimization(compiler_settings)

    optimization_runs = parse_optimization_runs(compiler_settings, optimization)

    prepared_params =
      %{}
      |> Map.put("optimization", optimization)
      |> Map.put("optimization_runs", optimization_runs)
      |> Map.put("evm_version", compiler_settings["evmVersion"] || "default")
      |> Map.put("compiler_version", compiler_version)
      |> Map.put("constructor_arguments", constructor_arguments)
      |> Map.put("contract_source_code", contract_source_code)
      |> Map.put("external_libraries", cast_libraries(compiler_settings["libraries"] || %{}))
      |> Map.put("name", contract_name)
      |> Map.put("file_path", if(save_file_path?, do: file_name))
      |> Map.put("secondary_sources", secondary_sources)
      |> Map.put("compiler_settings", if(is_standard_json?, do: compiler_settings))
      |> Map.put("partially_verified", match_type == "PARTIAL")
      |> Map.put("verified_via_sourcify", source["sourcify?"])
      |> Map.put("verified_via_eth_bytecode_db", automatically_verified?)
      |> Map.put("verified_via_verifier_alliance", source["verifier_alliance?"])
      |> Map.put("license_type", initial_params["license_type"])
      |> Map.put("is_blueprint", source["isBlueprint"])

    publish_smart_contract(address_hash, prepared_params, Jason.decode!(abi_string || "null"), save_file_path?)
  end

  defp parse_optimization_runs(compiler_settings, optimization) do
    if(optimization, do: compiler_settings["optimizer"]["runs"])
  end

  defp zksync_parse_optimization_runs(compiler_settings, optimization) do
    optimizer = Map.get(compiler_settings, "optimizer")

    if optimization do
      if optimizer && Map.has_key?(optimizer, "mode"), do: Map.get(optimizer, "mode"), else: "3"
    end
  end

  def extract_optimization(compiler_settings),
    do: (compiler_settings["optimizer"] && compiler_settings["optimizer"]["enabled"]) || false

  @doc """
    Publishes a verified smart contract.

    ## Parameters
    - `address_hash`: The address hash of the smart contract
    - `params`: The parameters for the smart contract
    - `abi`: The ABI of the smart contract
    - `verification_with_files?`: A boolean indicating whether the verification
      was performed with files or flattened code.
    - `file_path`: Optional file path for the smart contract source code

    ## Returns
    - `{:ok, %SmartContract{}}` if successful
    - `{:error, %Ecto.Changeset{}}` if there was an error
  """
  @spec publish_smart_contract(binary() | Explorer.Chain.Hash.t(), map(), map(), boolean(), String.t() | nil) ::
          {:ok, SmartContract.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def publish_smart_contract(address_hash, params, abi, verification_with_files?, file_path \\ nil) do
    attrs =
      if file_path do
        address_hash |> attributes(params, file_path, abi)
      else
        address_hash |> attributes(params, abi)
      end

    ok_or_error =
      SmartContract.create_or_update_smart_contract(
        address_hash,
        attrs,
        verification_with_files?
      )

    case ok_or_error do
      {:ok, _} ->
        Logger.info("Solidity smart-contract #{address_hash} successfully published")

      {:error, error} ->
        Logger.error("Solidity smart-contract #{address_hash} failed to publish: #{inspect(error)}")
    end

    ok_or_error
  end

  defp unverified_smart_contract(address_hash, params, error, error_message, verification_with_files? \\ false) do
    attrs =
      address_hash
      |> attributes(params)
      |> Helper.add_contract_code_md5()

    changeset =
      SmartContract.invalid_contract_changeset(
        %SmartContract{address_hash: address_hash},
        attrs,
        error,
        error_message,
        verification_with_files?
      )

    Logger.error("Solidity smart-contract verification #{address_hash} failed because of the error #{inspect(error)}")

    %{changeset | action: :insert}
  end

  defp attributes(address_hash, params, file_path, abi) do
    Map.put(attributes(address_hash, params, abi), :file_path, file_path)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp attributes(address_hash, params, abi \\ %{}) do
    constructor_arguments = params["constructor_arguments"]
    compiler_settings = params["compiler_settings"]

    clean_constructor_arguments = clear_constructor_arguments(constructor_arguments)

    clean_compiler_settings =
      if compiler_settings in ["", nil, %{}] do
        nil
      else
        compiler_settings
      end

    prepared_external_libraries = prepare_external_libraries(params["external_libraries"])

    compiler_version = CompilerVersion.get_strict_compiler_version(:solc, params["compiler_version"])

    base_attributes = %{
      address_hash: address_hash,
      name: params["name"],
      file_path: params["file_path"],
      compiler_version: compiler_version,
      evm_version: params["evm_version"],
      optimization_runs: params["optimization_runs"],
      optimization: params["optimization"],
      contract_source_code: params["contract_source_code"],
      constructor_arguments: clean_constructor_arguments,
      external_libraries: prepared_external_libraries,
      secondary_sources: params["secondary_sources"],
      abi: abi,
      verified_via_sourcify: params["verified_via_sourcify"] || false,
      verified_via_eth_bytecode_db: params["verified_via_eth_bytecode_db"] || false,
      verified_via_verifier_alliance: params["verified_via_verifier_alliance"] || false,
      partially_verified: params["partially_verified"] || false,
      autodetect_constructor_args: params["autodetect_constructor_args"],
      compiler_settings: clean_compiler_settings,
      license_type: prepare_license_type(params["license_type"]) || :none,
      is_blueprint: params["is_blueprint"] || false,
      language: (is_nil(abi) && :yul) || :solidity
    }

    base_attributes
    |> (&if(Application.get_env(:explorer, :chain_type) == :zksync,
          do: Map.put(&1, :zk_compiler_version, params["zk_compiler_version"]),
          else: &1
        )).()
  end

  @doc """
  Helper function to clean constructor arguments
  """
  @spec clear_constructor_arguments(String.t() | nil) :: String.t() | nil
  def clear_constructor_arguments(constructor_arguments) do
    if constructor_arguments != nil && constructor_arguments != "" do
      constructor_arguments
    else
      nil
    end
  end

  defp prepare_external_libraries(nil), do: []

  defp prepare_external_libraries(map) do
    map
    |> Enum.map(fn {key, value} ->
      %{name: key, address_hash: value}
    end)
  end

  defp add_external_libraries(%{"external_libraries" => _} = params, _external_libraries), do: params

  defp add_external_libraries(params, external_libraries) do
    clean_external_libraries =
      Enum.reduce(1..Application.get_env(:block_scout_web, :contract)[:verification_max_libraries], %{}, fn number,
                                                                                                            acc ->
        address_key = "library#{number}_address"
        name_key = "library#{number}_name"

        address = external_libraries[address_key]
        name = external_libraries[name_key]

        if is_nil(address) || address == "" || is_nil(name) || name == "" do
          acc
        else
          Map.put(acc, name, address)
        end
      end)

    Map.put(params, "external_libraries", clean_external_libraries)
  end

  defp maybe_add_zksync_specific_data(params) do
    if Application.get_env(:explorer, :chain_type) == :zksync do
      Map.put(params, "constructor_arguments", SmartContract.zksync_get_constructor_arguments(params["address_hash"]))
    else
      params
    end
  end
end
