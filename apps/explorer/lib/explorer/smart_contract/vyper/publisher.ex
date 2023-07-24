defmodule Explorer.SmartContract.Vyper.Publisher do
  @moduledoc """
  Module responsible to control Vyper contract verification.
  """

  import Explorer.SmartContract.Helper, only: [cast_libraries: 1]

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.CompilerVersion
  alias Explorer.SmartContract.Vyper.Verifier

  def publish(address_hash, params) do
    case Verifier.evaluate_authenticity(address_hash, params) do
      {
        :ok,
        %{
          "abi" => _abi_string,
          "compilerVersion" => _compiler_version,
          "constructorArguments" => _constructor_arguments,
          "contractName" => _contract_name,
          "fileName" => _file_name,
          "sourceFiles" => _sources,
          "compilerSettings" => _compiler_settings_string
        } = source
      } ->
        process_rust_verifier_response(source, address_hash, false, false)

      {:ok, %{abi: abi}} ->
        publish_smart_contract(address_hash, params, abi)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params, error, nil)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params, "Unexpected error", nil)}
    end
  end

  def publish(address_hash, params, files) do
    publish_inner(:evaluate_authenticity, [address_hash, params, files], address_hash, params, false)
  end

  def publish_standard_json(%{"address_hash" => address_hash} = params) do
    publish_inner(:evaluate_authenticity_standard_json, [params], address_hash, params, true)
  end

  defp publish_inner(fun, args, address_hash, params, standard_json?) do
    case apply(Verifier, fun, args) do
      {
        :ok,
        %{
          "abi" => _abi_string,
          "compilerVersion" => _compiler_version,
          "constructorArguments" => _constructor_arguments,
          "contractName" => _contract_name,
          "fileName" => _file_name,
          "sourceFiles" => _sources,
          "compilerSettings" => _compiler_settings_string
        } = source
      } ->
        process_rust_verifier_response(source, address_hash, true, standard_json?)

      {:ok, %{abi: abi}} ->
        publish_smart_contract(address_hash, params, abi)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params, error, nil, true)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params, "Unexpected error", nil, true)}
    end
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
        },
        address_hash,
        save_file_path?,
        standard_json?,
        automatically_verified? \\ false
      ) do
    secondary_sources =
      for {file, source} <- sources,
          file != file_name,
          do: %{"file_name" => file, "contract_source_code" => source, "address_hash" => address_hash}

    %{^file_name => contract_source_code} = sources

    compiler_settings = Jason.decode!(compiler_settings_string)

    prepared_params =
      %{}
      |> Map.put("compiler_version", compiler_version)
      |> Map.put("constructor_arguments", constructor_arguments)
      |> Map.put("contract_source_code", contract_source_code)
      |> Map.put("external_libraries", cast_libraries(compiler_settings["libraries"] || %{}))
      |> Map.put("name", contract_name)
      |> Map.put("file_path", if(save_file_path?, do: file_name))
      |> Map.put("secondary_sources", secondary_sources)
      |> Map.put("evm_version", compiler_settings["evmVersion"])
      |> Map.put("partially_verified", match_type == "PARTIAL")
      |> Map.put("verified_via_eth_bytecode_db", automatically_verified?)
      |> Map.put(
        "optimization",
        if(is_nil(compiler_settings["optimize"]), do: true, else: compiler_settings["optimize"])
      )
      |> Map.put("compiler_settings", if(standard_json?, do: compiler_settings))

    publish_smart_contract(address_hash, prepared_params, Jason.decode!(abi_string))
  end

  def publish_smart_contract(address_hash, params, abi) do
    Logger.info("Publish successfully verified Vyper smart-contract #{address_hash} into the DB")
    attrs = address_hash |> attributes(params, abi)

    Chain.create_smart_contract(attrs, attrs.external_libraries, attrs.secondary_sources)
  end

  defp unverified_smart_contract(address_hash, params, error, error_message, verification_with_files? \\ false) do
    attrs = attributes(address_hash, params)

    changeset =
      SmartContract.invalid_contract_changeset(
        %SmartContract{address_hash: address_hash},
        attrs,
        error,
        error_message,
        verification_with_files?
      )

    Logger.error("Vyper smart-contract verification #{address_hash} failed because of the error #{error}")

    %{changeset | action: :insert}
  end

  defp attributes(address_hash, params, abi \\ %{}) do
    constructor_arguments = params["constructor_arguments"]
    compiler_settings = params["compiler_settings"]

    clean_constructor_arguments =
      if constructor_arguments != nil && constructor_arguments != "" do
        constructor_arguments
      else
        nil
      end

    clean_compiler_settings =
      if compiler_settings in ["", nil, %{}] do
        nil
      else
        compiler_settings
      end

    compiler_version = CompilerVersion.get_strict_compiler_version(:vyper, params["compiler_version"])

    optimization = if is_nil(params["optimization"]), do: true, else: params["optimization"]

    %{
      address_hash: address_hash,
      name: params["name"],
      compiler_version: compiler_version,
      evm_version: params["evm_version"],
      optimization_runs: nil,
      optimization: optimization,
      contract_source_code: params["contract_source_code"],
      constructor_arguments: clean_constructor_arguments,
      external_libraries: [],
      secondary_sources: params["secondary_sources"],
      abi: abi,
      verified_via_sourcify: false,
      partially_verified: params["partially_verified"] || false,
      is_vyper_contract: true,
      file_path: params["file_path"],
      verified_via_eth_bytecode_db: params["verified_via_eth_bytecode_db"] || false,
      compiler_settings: clean_compiler_settings
    }
  end
end
