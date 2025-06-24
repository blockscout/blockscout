defmodule Explorer.SmartContract.Geas.Publisher do
  @moduledoc """
  Module responsible for verifying and publishing GEAS smart contracts.

  The verification process includes:
  1. Processing verification response from the Ethereum Bytecode DB
  2. Extracting contract source files and ABI
  3. Creating or updating the smart contract record in the database
  4. Handling verification failures by creating invalid changesets with error messages
  """

  require Logger

  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Helper
  alias Explorer.SmartContract.Solidity.Publisher, as: SolidityPublisher

  @doc """
  Processes the verification response from the Ethereum Bytecode DB for GEAS contracts.

  ## Parameters
  - `source`: Map containing verification response with GEAS-specific fields:
    - `"abi"`: Contract ABI as JSON string
    - `"compilerVersion"`: Version of the GEAS compiler used
    - `"constructorArguments"`: Constructor arguments (can be null)
    - `"contractName"`: Name of the contract
    - `"fileName"`: Main source file name (typically .eas extension)
    - `"sourceFiles"`: Map of file paths to source code contents
    - `"compilerSettings"`: Compiler settings as JSON string
    - `"matchType"`: Type of bytecode match ("FULL" or "PARTIAL")
  - `address_hash`: The contract's address hash as binary or `t:Explorer.Chain.Hash.t/0`
  - `initial_params`: Initial parameters from the verification request
  - `save_file_path?`: Boolean indicating whether to save the file path
  - `is_standard_json?`: Boolean indicating if this was a standard JSON verification
  - `automatically_verified?`: Boolean indicating if this was automatically verified

  ## Returns
  - `{:ok, smart_contract}` if verification and database storage succeed
  - `{:error, changeset}` if verification fails or there are validation errors
  """
  @spec process_rust_verifier_response(
          map(),
          binary() | Explorer.Chain.Hash.t(),
          map(),
          boolean(),
          boolean(),
          boolean()
        ) ::
          {:ok, Explorer.Chain.SmartContract.t()} | {:error, Ecto.Changeset.t()}
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
        save_file_path?,
        _is_standard_json?,
        automatically_verified? \\ false
      ) do
    secondary_sources =
      for {file, source_code} <- sources,
          file != file_name,
          do: %{
            "file_name" => file,
            "contract_source_code" => source_code,
            "address_hash" => address_hash
          }

    %{^file_name => contract_source_code} = sources

    compiler_settings = Jason.decode!(compiler_settings_string)

    prepared_params =
      %{}
      |> Map.put("compiler_version", compiler_version)
      |> Map.put("constructor_arguments", constructor_arguments)
      |> Map.put("contract_source_code", contract_source_code)
      |> Map.put("name", contract_name)
      |> Map.put("file_path", if(save_file_path?, do: file_name))
      |> Map.put("secondary_sources", secondary_sources)
      |> Map.put("partially_verified", match_type == "PARTIAL")
      |> Map.put("verified_via_eth_bytecode_db", automatically_verified?)
      |> Map.put("verified_via_verifier_alliance", source["verifier_alliance?"] || false)
      |> Map.put("compiler_settings", compiler_settings)
      |> Map.put("license_type", initial_params["license_type"])
      |> Map.put("is_blueprint", source["isBlueprint"] || false)

    publish_smart_contract(address_hash, prepared_params, Jason.decode!(abi_string || "null"), save_file_path?)
  end

  @doc """
  Stores information about a verified GEAS smart contract in the database.

  ## Parameters
  - `address_hash`: The contract's address hash as binary or `t:Explorer.Chain.Hash.t/0`
  - `params`: Map containing contract details
  - `abi`: Contract's ABI (Application Binary Interface)
  - `verification_with_files?`: Boolean indicating if verification used source files

  ## Returns
  - `{:ok, smart_contract}` if publishing succeeds
  - `{:error, changeset}` if there are validation errors
  - `{:error, message}` if the database operation fails
  """
  @spec publish_smart_contract(binary() | Explorer.Chain.Hash.t(), map(), map(), boolean()) ::
          {:ok, Explorer.Chain.SmartContract.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def publish_smart_contract(address_hash, params, abi, verification_with_files?) do
    attrs = address_hash |> attributes(params, abi)

    ok_or_error =
      SmartContract.create_or_update_smart_contract(
        address_hash,
        attrs,
        verification_with_files?
      )

    case ok_or_error do
      {:ok, _smart_contract} ->
        Logger.info("GEAS smart-contract #{address_hash} successfully published")

      {:error, error} ->
        Logger.error("GEAS smart-contract #{address_hash} failed to publish: #{inspect(error)}")
    end

    ok_or_error
  end

  # Private function to build contract attributes for database storage
  defp attributes(address_hash, params, abi) do
    constructor_arguments = params["constructor_arguments"]
    compiler_settings = params["compiler_settings"]

    clean_constructor_arguments = SolidityPublisher.clear_constructor_arguments(constructor_arguments)

    clean_compiler_settings =
      if compiler_settings in ["", nil, %{}] do
        nil
      else
        compiler_settings
      end

    %{
      address_hash: address_hash,
      name: params["name"],
      compiler_version: params["compiler_version"],
      evm_version: nil,
      optimization_runs: nil,
      optimization: false,
      contract_source_code: params["contract_source_code"],
      constructor_arguments: clean_constructor_arguments,
      external_libraries: [],
      secondary_sources: params["secondary_sources"],
      abi: abi,
      verified_via_sourcify: false,
      verified_via_eth_bytecode_db: params["verified_via_eth_bytecode_db"] || false,
      verified_via_verifier_alliance: params["verified_via_verifier_alliance"] || false,
      partially_verified: params["partially_verified"] || false,
      file_path: params["file_path"],
      compiler_settings: clean_compiler_settings,
      license_type: Helper.prepare_license_type(params["license_type"]) || :none,
      is_blueprint: params["is_blueprint"] || false,
      language: :geas
    }
  end
end
