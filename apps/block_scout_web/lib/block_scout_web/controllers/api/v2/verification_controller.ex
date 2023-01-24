defmodule BlockScoutWeb.API.V2.VerificationController do
  use BlockScoutWeb, :controller

  import Explorer.SmartContract.Solidity.Verifier, only: [parse_boolean: 1]

  alias BlockScoutWeb.AccessHelpers
  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.Chain
  alias Explorer.SmartContract.Solidity.PublisherWorker, as: SolidityPublisherWorker
  alias Explorer.SmartContract.Solidity.PublishHelper
  alias Explorer.SmartContract.Vyper.PublisherWorker, as: VyperPublisherWorker
  alias Explorer.SmartContract.{CompilerVersion, RustVerifierInterface, Solidity.CodeCompiler}

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def config(conn, _params) do
    evm_versions = CodeCompiler.allowed_evm_versions()
    solidity_compiler_versions = CompilerVersion.fetch_version_list(:solc)
    vyper_compiler_versions = CompilerVersion.fetch_version_list(:vyper)

    verification_options =
      ["flattened_code", "standard_input", "vyper_code"]
      |> (&if(Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Sourcify)[:enabled],
            do: ["sourcify" | &1],
            else: &1
          )).()
      |> (&if(RustVerifierInterface.enabled?(), do: ["multi_part" | &1], else: &1)).()

    conn
    |> json(%{
      evm_versions: evm_versions,
      solidity_compiler_versions: solidity_compiler_versions,
      vyper_compiler_versions: vyper_compiler_versions,
      verification_options: verification_options
    })
  end

  def verification_via_flattened_code(
        conn,
        %{"address_hash" => address_hash_string, "compiler_version" => compiler_version, "source_code" => source_code} =
          params
      ) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:already_verified, false} <- {:already_verified, Chain.smart_contract_fully_verified?(address_hash)} do
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

      Que.add(SolidityPublisherWorker, {"flattened_api_v2", verification_params})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: "Verification started"})
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  def verification_via_standard_input(
        conn,
        %{"address_hash" => address_hash_string, "files" => files, "compiler_version" => compiler_version} = params
      ) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:already_verified, false} <- {:already_verified, Chain.smart_contract_fully_verified?(address_hash)},
         files_array <- PublishHelper.prepare_files_array(files),
         {:no_json_file, %Plug.Upload{path: path}} <-
           {:no_json_file, PublishHelper.get_one_json(files_array)},
         {:file_error, {:ok, json_input}} <- {:file_error, File.read(path)} do
      verification_params =
        %{
          "address_hash" => String.downcase(address_hash_string),
          "compiler_version" => compiler_version
        }
        |> Map.put("autodetect_constructor_args", Map.get(params, "autodetect_constructor_args", true))
        |> Map.put("constructor_arguments", Map.get(params, "constructor_args", ""))
        |> Map.put("name", Map.get(params, "contract_name", ""))

      Que.add(SolidityPublisherWorker, {"json_api_v2", verification_params, json_input})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: "Verification started"})
    end
  end

  def verification_via_sourcify(conn, %{"address_hash" => address_hash_string, "files" => files} = params) do
    with {:not_found, true} <-
           {:not_found, Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Sourcify)[:enabled]},
         {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:already_verified, false} <- {:already_verified, Chain.smart_contract_fully_verified?(address_hash)},
         files_array <- PublishHelper.prepare_files_array(files),
         {:no_json_file, %Plug.Upload{path: _path}} <-
           {:no_json_file, PublishHelper.get_one_json(files_array)},
         files_content <- PublishHelper.read_files(files_array) do
      Que.add(SolidityPublisherWorker, {"sourcify_api_v2", address_hash_string, files_content, conn})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: "Verification started"})
    end
  end

  def verification_via_multi_part(
        conn,
        %{"address_hash" => address_hash_string, "compiler_version" => compiler_version, "files" => files} = params
      ) do
    with {:not_found, true} <- {:not_found, RustVerifierInterface.enabled?()},
         {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:already_verified, false} <- {:already_verified, Chain.smart_contract_fully_verified?(address_hash)},
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
        |> Map.values()
        |> PublishHelper.read_files()

      Que.add(SolidityPublisherWorker, {"multipart_api_v2", verification_params, files_array})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: "Verification started"})
    end
  end

  def verification_via_vyper_code(
        conn,
        %{"address_hash" => address_hash_string, "compiler_version" => compiler_version, "source_code" => source_code} =
          params
      ) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:already_verified, false} <- {:already_verified, Chain.smart_contract_fully_verified?(address_hash)} do
      verification_params =
        %{
          "address_hash" => String.downcase(address_hash_string),
          "compiler_version" => compiler_version,
          "contract_source_code" => source_code
        }
        |> Map.put("constructor_arguments", Map.get(params, "constructor_args", "") || "")
        |> Map.put("name", Map.get(params, "contract_name", "Vyper_contract"))

      Que.add(VyperPublisherWorker, {address_hash_string, verification_params})

      conn
      |> put_view(ApiView)
      |> render(:message, %{message: "Verification started"})
    end
  end
end
