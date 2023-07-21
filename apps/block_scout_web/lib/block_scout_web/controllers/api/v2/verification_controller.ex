defmodule BlockScoutWeb.API.V2.VerificationController do
  use BlockScoutWeb, :controller

  import Explorer.SmartContract.Solidity.Verifier, only: [parse_boolean: 1]

  require Logger

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.Chain
  alias Explorer.SmartContract.Solidity.PublisherWorker, as: SolidityPublisherWorker
  alias Explorer.SmartContract.Solidity.PublishHelper
  alias Explorer.SmartContract.Vyper.PublisherWorker, as: VyperPublisherWorker
  alias Explorer.SmartContract.{CompilerVersion, RustVerifierInterface, Solidity.CodeCompiler}

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @api_true [api?: true]
  @sc_verification_started "Smart-contract verification started"

  def config(conn, _params) do
    solidity_compiler_versions = CompilerVersion.fetch_version_list(:solc)
    vyper_compiler_versions = CompilerVersion.fetch_version_list(:vyper)

    verification_options =
      ["flattened-code", "standard-input", "vyper-code"]
      |> (&if(Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Sourcify)[:enabled],
            do: ["sourcify" | &1],
            else: &1
          )).()
      |> (&if(RustVerifierInterface.enabled?(),
            do: ["multi-part", "vyper-multi-part", "vyper-standard-input"] ++ &1,
            else: &1
          )).()

    conn
    |> json(%{
      solidity_evm_versions: CodeCompiler.evm_versions(:solidity),
      solidity_compiler_versions: solidity_compiler_versions,
      vyper_compiler_versions: vyper_compiler_versions,
      verification_options: verification_options,
      vyper_evm_versions: CodeCompiler.evm_versions(:vyper),
      is_rust_verifier_microservice_enabled: RustVerifierInterface.enabled?()
    })
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
              do: Map.put(&1, "optimization_runs", Map.get(params, "optimization_runs", 200)),
              else: &1
            )).()
        |> Map.put("evm_version", Map.get(params, "evm_version", "default"))
        |> Map.put("autodetect_constructor_args", Map.get(params, "autodetect_constructor_args", true))
        |> Map.put("constructor_arguments", Map.get(params, "constructor_args", ""))
        |> Map.put("name", Map.get(params, "contract_name", ""))
        |> Map.put("external_libraries", Map.get(params, "libraries", %{}))
        |> Map.put("is_yul", Map.get(params, "is_yul_contract", false))

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
              do: Map.put(&1, "optimization_runs", Map.get(params, "optimization_runs", 200)),
              else: &1
            )).()
        |> Map.put("evm_version", Map.get(params, "evm_version", "default"))
        |> Map.put("external_libraries", json)

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
        "input" => json_input
      }

      log_sc_verification_started(address_hash_string)
      Que.add(VyperPublisherWorker, {"vyper_standard_json", verification_params})

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
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:already_verified, false} <-
           {:already_verified, Chain.smart_contract_fully_verified?(address_hash, @api_true)} do
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
