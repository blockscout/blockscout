defmodule BlockScoutWeb.API.V2.VerificationController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import Explorer.Helper, only: [parse_boolean: 1]

  require Logger

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Solidity.PublisherWorker, as: SolidityPublisherWorker
  alias Explorer.SmartContract.Solidity.PublishHelper
  alias Explorer.SmartContract.Stylus.PublisherWorker, as: StylusPublisherWorker
  alias Explorer.SmartContract.Vyper.PublisherWorker, as: VyperPublisherWorker
  alias Explorer.SmartContract.{CompilerVersion, RustVerifierInterface, Solidity.CodeCompiler, StylusVerifierInterface}

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @api_true [api?: true]
  @sc_verification_started "Smart-contract verification started"
  @zk_optimization_modes ["0", "1", "2", "3", "s", "z"]

  if @chain_type == :zksync do
    @optimization_runs "0"
  else
    @optimization_runs 200
  end

  def config(conn, _params) do
    solidity_compiler_versions = CompilerVersion.fetch_version_list(:solc)
    vyper_compiler_versions = CompilerVersion.fetch_version_list(:vyper)

    verification_options = get_verification_options()

    base_config =
      %{
        solidity_evm_versions: CodeCompiler.evm_versions(:solidity),
        solidity_compiler_versions: solidity_compiler_versions,
        vyper_compiler_versions: vyper_compiler_versions,
        verification_options: verification_options,
        vyper_evm_versions: CodeCompiler.evm_versions(:vyper),
        is_rust_verifier_microservice_enabled: RustVerifierInterface.enabled?(),
        license_types: Enum.into(SmartContract.license_types_enum(), %{})
      }

    config =
      base_config
      |> maybe_add_zk_options()
      |> maybe_add_stylus_options()

    conn
    |> json(config)
  end

  defp get_verification_options do
    if Application.get_env(:explorer, :chain_type) == :zksync do
      ["standard-input"]
    else
      ["flattened-code", "standard-input", "vyper-code"]
      |> (&if(Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Sourcify)[:enabled],
            do: ["sourcify" | &1],
            else: &1
          )).()
      |> (&if(RustVerifierInterface.enabled?(),
            do: ["multi-part", "vyper-multi-part", "vyper-standard-input"] ++ &1,
            else: &1
          )).()
      |> (&if(StylusVerifierInterface.enabled?(),
            do: ["stylus-github-repository" | &1],
            else: &1
          )).()
    end
  end

  defp maybe_add_zk_options(config) do
    if Application.get_env(:explorer, :chain_type) == :zksync do
      zk_compiler_versions = CompilerVersion.fetch_version_list(:zk)

      config
      |> Map.put(:zk_compiler_versions, zk_compiler_versions)
      |> Map.put(:zk_optimization_modes, @zk_optimization_modes)
    else
      config
    end
  end

  # Adds Stylus compiler versions to config if Stylus verification is enabled
  defp maybe_add_stylus_options(config) do
    if StylusVerifierInterface.enabled?() do
      config
      |> Map.put(:stylus_compiler_versions, CompilerVersion.fetch_version_list(:stylus))
    else
      config
    end
  end

  def verification_via_flattened_code(
        conn,
        %{"address_hash" => address_hash_string, "compiler_version" => compiler_version, "source_code" => source_code} =
          params
      ) do
    Logger.info("API v2 smart-contract #{address_hash_string} verification via flattened file")

    with :validated <- validate_address(params) do
      verification_params =
        %{
          "address_hash" => String.downcase(address_hash_string),
          "compiler_version" => compiler_version,
          "contract_source_code" => source_code
        }
        |> Map.put("optimization", Map.get(params, "is_optimization_enabled", false))
        |> (&if(params |> Map.get("is_optimization_enabled", false) |> parse_boolean(),
              do: Map.put(&1, "optimization_runs", Map.get(params, "optimization_runs", @optimization_runs)),
              else: &1
            )).()
        |> Map.put("evm_version", Map.get(params, "evm_version", "default"))
        |> Map.put("autodetect_constructor_args", Map.get(params, "autodetect_constructor_args", true))
        |> Map.put("constructor_arguments", Map.get(params, "constructor_args", ""))
        |> Map.put("name", Map.get(params, "contract_name", ""))
        |> Map.put("external_libraries", Map.get(params, "libraries", %{}))
        |> Map.put("is_yul", Map.get(params, "is_yul_contract", false))
        |> Map.put("license_type", Map.get(params, "license_type"))

      log_sc_verification_started(address_hash_string)
      Que.add(SolidityPublisherWorker, {"flattened_api_v2", verification_params})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: @sc_verification_started})
    end
  end

  def verification_via_standard_input(
        conn,
        %{"address_hash" => address_hash_string, "files" => _files, "compiler_version" => compiler_version} = params
      ) do
    Logger.info("API v2 smart-contract #{address_hash_string} verification via standard json input")

    with {:json_input, json_input} <- validate_params_standard_json_input(params) do
      verification_params =
        %{
          "address_hash" => String.downcase(address_hash_string),
          "compiler_version" => compiler_version
        }
        |> Map.put("autodetect_constructor_args", Map.get(params, "autodetect_constructor_args", true))
        |> Map.put("constructor_arguments", Map.get(params, "constructor_args", ""))
        |> Map.put("name", Map.get(params, "contract_name", ""))
        |> Map.put("license_type", Map.get(params, "license_type"))
        |> (&if(Application.get_env(:explorer, :chain_type) == :zksync,
              do: Map.put(&1, "zk_compiler_version", Map.get(params, "zk_compiler_version")),
              else: &1
            )).()

      log_sc_verification_started(address_hash_string)
      Que.add(SolidityPublisherWorker, {"json_api_v2", verification_params, json_input})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: @sc_verification_started})
    end
  end

  def verification_via_sourcify(conn, %{"address_hash" => address_hash_string, "files" => files} = params) do
    Logger.info("API v2 smart-contract #{address_hash_string} verification via Sourcify")

    with {:not_found, true} <-
           {:not_found, Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Sourcify)[:enabled]},
         :validated <- validate_address(params),
         files_array <- PublishHelper.prepare_files_array(files),
         {:no_json_file, %Plug.Upload{path: _path}} <-
           {:no_json_file, PublishHelper.get_one_json(files_array)},
         files_content <- PublishHelper.read_files(files_array) do
      chosen_contract = params["chosen_contract_index"]

      log_sc_verification_started(address_hash_string)

      Que.add(
        SolidityPublisherWorker,
        {"sourcify_api_v2", String.downcase(address_hash_string), files_content, conn, chosen_contract}
      )

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: @sc_verification_started})
    end
  end

  def verification_via_multi_part(
        conn,
        %{"address_hash" => address_hash_string, "compiler_version" => compiler_version, "files" => files} = params
      ) do
    Logger.info("API v2 smart-contract #{address_hash_string} verification via multipart")

    with :verifier_enabled <- check_microservice(),
         :validated <- validate_address(params),
         libraries <- Map.get(params, "libraries", "{}"),
         {:libs_format, {:ok, json}} <- {:libs_format, Jason.decode(libraries)} do
      verification_params =
        %{
          "address_hash" => String.downcase(address_hash_string),
          "compiler_version" => compiler_version
        }
        |> Map.put("optimization", Map.get(params, "is_optimization_enabled", false))
        |> (&if(params |> Map.get("is_optimization_enabled", false) |> parse_boolean(),
              do: Map.put(&1, "optimization_runs", Map.get(params, "optimization_runs", @optimization_runs)),
              else: &1
            )).()
        |> Map.put("evm_version", Map.get(params, "evm_version", "default"))
        |> Map.put("external_libraries", json)
        |> Map.put("license_type", Map.get(params, "license_type"))

      files_array =
        files
        |> PublishHelper.prepare_files_array()
        |> PublishHelper.read_files()

      log_sc_verification_started(address_hash_string)
      Que.add(SolidityPublisherWorker, {"multipart_api_v2", verification_params, files_array})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: @sc_verification_started})
    end
  end

  def verification_via_vyper_code(
        conn,
        %{"address_hash" => address_hash_string, "compiler_version" => compiler_version, "source_code" => source_code} =
          params
      ) do
    with :validated <- validate_address(params) do
      verification_params =
        %{
          "address_hash" => String.downcase(address_hash_string),
          "compiler_version" => compiler_version,
          "contract_source_code" => source_code
        }
        |> Map.put("constructor_arguments", Map.get(params, "constructor_args", "") || "")
        |> Map.put("name", Map.get(params, "contract_name", "Vyper_contract"))
        |> Map.put("evm_version", Map.get(params, "evm_version"))
        |> Map.put("license_type", Map.get(params, "license_type"))

      log_sc_verification_started(address_hash_string)
      Que.add(VyperPublisherWorker, {"vyper_flattened", verification_params})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: @sc_verification_started})
    end
  end

  def verification_via_vyper_multipart(
        conn,
        %{"address_hash" => address_hash_string, "compiler_version" => compiler_version, "files" => files} = params
      ) do
    Logger.info("API v2 vyper smart-contract #{address_hash_string} verification")

    with :verifier_enabled <- check_microservice(),
         :validated <- validate_address(params) do
      interfaces = parse_interfaces(params["interfaces"])

      verification_params =
        %{
          "address_hash" => String.downcase(address_hash_string),
          "compiler_version" => compiler_version
        }
        |> Map.put("evm_version", Map.get(params, "evm_version"))
        |> Map.put("interfaces", interfaces)
        |> Map.put("license_type", Map.get(params, "license_type"))

      files_array =
        files
        |> PublishHelper.prepare_files_array()
        |> PublishHelper.read_files()

      log_sc_verification_started(address_hash_string)
      Que.add(VyperPublisherWorker, {"vyper_multipart", verification_params, files_array})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: @sc_verification_started})
    end
  end

  def verification_via_vyper_standard_input(
        conn,
        %{"address_hash" => address_hash_string, "files" => _files, "compiler_version" => compiler_version} = params
      ) do
    Logger.info("API v2 vyper smart-contract #{address_hash_string} verification via standard json input")

    with :verifier_enabled <- check_microservice(),
         {:json_input, json_input} <- validate_params_standard_json_input(params) do
      verification_params = %{
        "address_hash" => String.downcase(address_hash_string),
        "compiler_version" => compiler_version,
        "input" => json_input,
        "license_type" => Map.get(params, "license_type")
      }

      log_sc_verification_started(address_hash_string)
      Que.add(VyperPublisherWorker, {"vyper_standard_json", verification_params})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: @sc_verification_started})
    end
  end

  @doc """
    Initiates verification of a Stylus smart contract using its GitHub repository source code.

    Validates the request parameters and queues the verification job to be processed
    asynchronously by the Stylus publisher worker.

    ## Parameters
    - `conn`: The connection struct
    - `params`: A map containing:
      - `address_hash`: Contract address to verify
      - `cargo_stylus_version`: Version of cargo-stylus used for deployment
      - `repository_url`: GitHub repository URL containing contract code
      - `commit`: Git commit hash used for deployment
      - `path_prefix`: Optional path prefix if contract is not in repository root

    ## Returns
    - JSON response with:
      - Success message if verification request is queued successfully
      - Error message if:
        - Stylus verification is not enabled
        - Address format is invalid
        - Contract is already verified
        - Access is restricted
  """
  @spec verification_via_stylus_github_repository(Plug.Conn.t(), %{String.t() => any()}) ::
          {:already_verified, true}
          | {:format, :error}
          | {:not_found, false | nil}
          | {:restricted_access, true}
          | Plug.Conn.t()
  def verification_via_stylus_github_repository(
        conn,
        %{
          "address_hash" => address_hash_string,
          "cargo_stylus_version" => _,
          "repository_url" => _,
          "commit" => _,
          "path_prefix" => _
        } = params
      ) do
    Logger.info("API v2 stylus smart-contract #{address_hash_string} verification via github repository")

    with {:not_found, true} <- {:not_found, StylusVerifierInterface.enabled?()},
         :validated <- validate_address(params) do
      log_sc_verification_started(address_hash_string)
      Que.add(StylusPublisherWorker, {"github_repository", params})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: @sc_verification_started})
    end
  end

  defp parse_interfaces(interfaces) do
    cond do
      is_binary(interfaces) ->
        case Jason.decode(interfaces) do
          {:ok, map} ->
            map

          _ ->
            nil
        end

      is_map(interfaces) ->
        interfaces
        |> PublishHelper.prepare_files_array()
        |> PublishHelper.read_files()

      true ->
        nil
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp validate_params_standard_json_input(%{"files" => files} = params) do
    with :validated <- validate_address(params),
         files_array <- PublishHelper.prepare_files_array(files),
         {:no_json_file, %Plug.Upload{path: path}} <-
           {:no_json_file, PublishHelper.get_one_json(files_array)},
         {:file_error, {:ok, json_input}} <- {:file_error, File.read(path)} do
      {:json_input, json_input}
    end
  end

  defp validate_address(%{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:not_a_smart_contract, bytecode} when bytecode != "0x" <-
           {:not_a_smart_contract, Chain.smart_contract_bytecode(address_hash, @api_true)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:already_verified, false} <-
           {:already_verified, SmartContract.verified_with_full_match?(address_hash, @api_true)} do
      :validated
    end
  end

  defp check_microservice do
    with {:not_found, true} <- {:not_found, RustVerifierInterface.enabled?()} do
      :verifier_enabled
    end
  end

  defp log_sc_verification_started(address_hash_string) do
    Logger.info("API v2 smart-contract #{address_hash_string} verification request sent to the microservice")
  end
end
