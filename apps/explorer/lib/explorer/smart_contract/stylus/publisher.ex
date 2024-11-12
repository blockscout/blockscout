defmodule Explorer.SmartContract.Stylus.Publisher do
  @moduledoc """
  Module responsible to control the contract verification.
  """

  require Logger

  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Helper
  alias Explorer.SmartContract.Stylus.Verifier

  @default_file_name "src/lib.rs"

  @sc_verification_via_github_repository_started "Smart-contract verification via Github repository started"

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

  defp publish_smart_contract(address_hash, params, abi) do
    attrs = address_hash |> attributes(params, abi)

    create_or_update_smart_contract(address_hash, attrs)
  end

  @spec create_or_update_smart_contract(binary() | Explorer.Chain.Hash.t(), map()) ::
          {:error, Ecto.Changeset.t() | String.t()} | {:ok, Explorer.Chain.SmartContract.t()}
  defp create_or_update_smart_contract(address_hash, attrs) do
    Logger.info("Publish successfully verified Stylus smart-contract #{address_hash} into the DB")

    if SmartContract.verified?(address_hash) do
      SmartContract.update_smart_contract(attrs, attrs.external_libraries, attrs.secondary_sources)
    else
      SmartContract.create_smart_contract(attrs, attrs.external_libraries, attrs.secondary_sources)
    end
  end

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
      is_vyper_contract: false,
      autodetect_constructor_args: false,
      is_yul: false,
      compiler_settings: nil,
      license_type: :none,
      is_blueprint: false,
      language: :stylus_rust,
      package_name: params["package_name"],
      github_repository_metadata: params["github_repository_metadata"]
    }
  end
end
