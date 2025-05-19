defmodule Explorer.SmartContract.Stylus.Publisher do
  @moduledoc """
    Module responsible for verifying and publishing Stylus smart contracts.

    The verification process includes:
    1. Initiating verification through a microservice that compares GitHub repository
      source code against deployed bytecode
    2. Processing the verification response, including ABI and source files
    3. Creating or updating the smart contract record in the database
    4. Handling verification failures by creating invalid changesets with error messages
  """

  require Logger

  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Helper
  alias Explorer.SmartContract.Stylus.Verifier

  @default_file_name "src/lib.rs"

  @sc_verification_via_github_repository_started "Smart-contract verification via Github repository started"

  @doc """
    Verifies and publishes a Stylus smart contract using GitHub repository source code.

    Initiates verification of a contract through the verification microservice. On
    successful verification, processes and stores the contract details in the
    database. On failure, creates an invalid changeset with appropriate error
    messages.

    ## Parameters
    - `address_hash`: The contract's address hash as binary or `t:Explorer.Chain.Hash.t/0`
    - `params`: Map containing verification parameters:
      - `"cargo_stylus_version"`: Version of cargo-stylus used for deployment
      - `"repository_url"`: GitHub repository URL containing contract code
      - `"commit"`: Git commit hash used for deployment
      - `"path_prefix"`: Optional path prefix if contract is not in repository root

    ## Returns
    - `{:ok, smart_contract}` if verification and database storage succeed
    - `{:error, changeset}` if verification fails or there are validation errors
  """
  @spec publish(binary() | Explorer.Chain.Hash.t(), %{String.t() => any()}) ::
          {:error, Ecto.Changeset.t()} | {:ok, Explorer.Chain.SmartContract.t()}
  def publish(address_hash, params) do
    Logger.info(@sc_verification_via_github_repository_started)

    case Verifier.evaluate_authenticity(address_hash, params) do
      {
        :ok,
        %{
          "abi" => _,
          "cargo_stylus_version" => _,
          "contract_name" => _,
          "files" => _,
          "package_name" => _,
          "github_repository_metadata" => _
        } = result_params
      } ->
        process_verifier_response(result_params, address_hash)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params, error, nil)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params, "Unexpected error", nil)}
    end
  end

  # Processes successful Stylus contract verification response and stores contract data.
  #
  # Takes the verification response from `evaluate_authenticity/2` containing verified contract
  # details and prepares them for storage in the database. The main source file is extracted
  # from `files` map using the default filename, while other files are stored as secondary
  # sources.
  #
  # ## Parameters
  # - `response`: Verification response map containing:
  #   - `abi`: Contract ABI as JSON string
  #   - `cargo_stylus_version`: Version of cargo-stylus used
  #   - `contract_name`: Name of the contract
  #   - `files`: Map of file paths to source code contents
  #   - `package_name`: Package name of the contract
  #   - `github_repository_metadata`: Repository metadata
  # - `address_hash`: The contract's address hash as binary or `t:Explorer.Chain.Hash.t/0`
  #
  # ## Returns
  # - `{:ok, smart_contract}` if database storage succeeds
  # - `{:error, changeset}` if there are validation errors
  # - `{:error, message}` if the database operation fails
  @spec process_verifier_response(%{String.t() => any()}, binary() | Explorer.Chain.Hash.t()) ::
          {:ok, Explorer.Chain.SmartContract.t()} | {:error, Ecto.Changeset.t() | String.t()}
  defp process_verifier_response(
         %{
           "abi" => abi_string,
           "cargo_stylus_version" => cargo_stylus_version,
           "contract_name" => contract_name,
           "files" => files,
           "package_name" => package_name,
           "github_repository_metadata" => github_repository_metadata
         },
         address_hash
       ) do
    secondary_sources =
      for {file, code} <- files,
          file != @default_file_name,
          do: %{"file_name" => file, "contract_source_code" => code, "address_hash" => address_hash}

    contract_source_code = files[@default_file_name]

    prepared_params =
      %{}
      |> Map.put("compiler_version", cargo_stylus_version)
      |> Map.put("contract_source_code", contract_source_code)
      |> Map.put("name", contract_name)
      |> Map.put("file_path", contract_source_code && @default_file_name)
      |> Map.put("secondary_sources", secondary_sources)
      |> Map.put("package_name", package_name)
      |> Map.put("github_repository_metadata", github_repository_metadata)

    publish_smart_contract(address_hash, prepared_params, Jason.decode!(abi_string || "null"))
  end

  # Stores information about a verified Stylus smart contract in the database.
  #
  # ## Parameters
  # - `address_hash`: The contract's address hash as binary or `t:Explorer.Chain.Hash.t/0`
  # - `params`: Map containing contract details:
  #   - `name`: Contract name
  #   - `file_path`: Path to the contract source file
  #   - `compiler_version`: Version of the Stylus compiler
  #   - `contract_source_code`: Source code of the contract
  #   - `secondary_sources`: Additional source files
  #   - `package_name`: Package name for Stylus contract
  #   - `github_repository_metadata`: Repository metadata
  # - `abi`: Contract's ABI (Application Binary Interface)
  #
  # ## Returns
  # - `{:ok, smart_contract}` if publishing succeeds
  # - `{:error, changeset}` if there are validation errors
  # - `{:error, message}` if the database operation fails
  @spec publish_smart_contract(binary() | Explorer.Chain.Hash.t(), %{String.t() => any()}, map()) ::
          {:error, Ecto.Changeset.t() | String.t()} | {:ok, Explorer.Chain.SmartContract.t()}
  defp publish_smart_contract(address_hash, params, abi) do
    attrs = address_hash |> attributes(params, abi)

    ok_or_error = SmartContract.create_or_update_smart_contract(address_hash, attrs, false)

    case ok_or_error do
      {:ok, _} ->
        Logger.info("Stylus smart-contract #{address_hash} successfully published")

      {:error, error} ->
        Logger.error("Stylus smart-contract #{address_hash} failed to publish: #{inspect(error)}")
    end

    ok_or_error
  end

  # Creates an invalid changeset for a Stylus smart contract that failed verification.
  #
  # Prepares contract attributes with MD5 hash of bytecode and creates an invalid changeset
  # with appropriate error messages. The changeset is marked with `:insert` action to
  # indicate a failed verification attempt.
  #
  # ## Parameters
  # - `address_hash`: The contract's address hash
  # - `params`: Map containing contract details from verification attempt
  # - `error`: The verification error that occurred
  # - `error_message`: Optional custom error message
  # - `verification_with_files?`: Boolean indicating if verification used source files.
  #   Defaults to `false`
  #
  # ## Returns
  # An invalid `t:Ecto.Changeset.t/0` with:
  # - Contract attributes including MD5 hash of bytecode
  # - Error message attached to appropriate field
  # - Action set to `:insert`
  @spec unverified_smart_contract(binary() | Explorer.Chain.Hash.t(), %{String.t() => any()}, any(), any(), boolean()) ::
          Ecto.Changeset.t()
  defp unverified_smart_contract(address_hash, params, error, error_message, verification_with_files? \\ false) do
    attrs =
      address_hash
      |> attributes(params |> Map.put("compiler_version", params["cargo_stylus_version"]))
      |> Helper.add_contract_code_md5()

    changeset =
      SmartContract.invalid_contract_changeset(
        %SmartContract{address_hash: address_hash},
        attrs,
        error,
        error_message,
        verification_with_files?
      )

    Logger.error("Stylus smart-contract verification #{address_hash} failed because of the error #{inspect(error)}")

    %{changeset | action: :insert}
  end

  defp attributes(address_hash, params, abi \\ %{}) do
    %{
      address_hash: address_hash,
      name: params["name"],
      file_path: params["file_path"],
      compiler_version: params["compiler_version"],
      evm_version: nil,
      optimization_runs: nil,
      optimization: false,
      contract_source_code: params["contract_source_code"],
      constructor_arguments: nil,
      external_libraries: [],
      secondary_sources: params["secondary_sources"],
      abi: abi,
      verified_via_sourcify: false,
      verified_via_eth_bytecode_db: false,
      verified_via_verifier_alliance: false,
      partially_verified: false,
      autodetect_constructor_args: false,
      compiler_settings: nil,
      license_type: :none,
      is_blueprint: false,
      language: :stylus_rust,
      package_name: params["package_name"],
      github_repository_metadata: params["github_repository_metadata"]
    }
  end
end
