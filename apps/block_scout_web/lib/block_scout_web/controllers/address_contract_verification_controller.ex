defmodule BlockScoutWeb.AddressContractVerificationController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.RPC.ContractController
  alias BlockScoutWeb.Controller
  alias Ecto.Changeset
  alias Explorer.Chain
  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.{CompilerVersion, Solidity.CodeCompiler}
  alias Explorer.SmartContract.Solidity.PublisherWorker, as: SolidityPublisherWorker
  alias Explorer.SmartContract.Vyper.PublisherWorker, as: VyperPublisherWorker
  alias Explorer.ThirdPartyIntegrations.Sourcify

  def new(conn, %{"address_id" => address_hash_string}) do
    if Chain.smart_contract_fully_verified?(address_hash_string) do
      address_path =
        conn
        |> address_path(:show, address_hash_string)
        |> Controller.full_path()

      redirect(conn, to: address_path)
    else
      changeset =
        SmartContract.changeset(
          %SmartContract{address_hash: address_hash_string},
          %{}
        )

      compiler_versions =
        case CompilerVersion.fetch_versions(:solc) do
          {:ok, compiler_versions} ->
            compiler_versions

          {:error, _} ->
            []
        end

      render(conn, "new.html",
        changeset: changeset,
        compiler_versions: compiler_versions,
        evm_versions: CodeCompiler.allowed_evm_versions(),
        address_hash: address_hash_string
      )
    end
  end

  def create(
        conn,
        %{
          "smart_contract" => smart_contract,
          "external_libraries" => external_libraries
        }
      ) do
    Que.add(SolidityPublisherWorker, {smart_contract["address_hash"], smart_contract, external_libraries, conn})

    send_resp(conn, 204, "")
  end

  def create(
        conn,
        %{
          "smart_contract" => smart_contract
        }
      ) do
    Que.add(VyperPublisherWorker, {smart_contract["address_hash"], smart_contract, conn})

    send_resp(conn, 204, "")
  end

  def create(
        conn,
        %{
          "address_hash" => address_hash_string,
          "file" => files
        }
      ) do
    files_array = prepare_files_array(files)

    json_files =
      files_array
      |> Enum.filter(fn file -> file.content_type == "application/json" end)

    json_file = json_files |> Enum.at(0)

    if json_file do
      if Chain.smart_contract_fully_verified?(address_hash_string) do
        EventsPublisher.broadcast(
          prepare_verification_error(
            "This contract already verified in Blockscout.",
            address_hash_string,
            conn
          ),
          :on_demand
        )
      else
        case Sourcify.check_by_address(address_hash_string) do
          {:ok, _verified_status} ->
            get_metadata_and_publish(address_hash_string, conn)

          _ ->
            verify_and_publish(address_hash_string, files_array, conn)
        end
      end
    else
      EventsPublisher.broadcast(
        prepare_verification_error(
          "Please attach JSON file with metadata of contract's compilation.",
          address_hash_string,
          conn
        ),
        :on_demand
      )
    end

    send_resp(conn, 204, "")
  end

  def create(conn, _params) do
    Que.add(SolidityPublisherWorker, {"", %{}, %{}, conn})

    send_resp(conn, 204, "")
  end

  defp verify_and_publish(address_hash_string, files_array, conn) do
    case Sourcify.verify(address_hash_string, files_array) do
      {:ok, _verified_status} ->
        case Sourcify.check_by_address(address_hash_string) do
          {:ok, _verified_status} ->
            get_metadata_and_publish(address_hash_string, conn)

          {:error, %{"error" => error}} ->
            EventsPublisher.broadcast(
              prepare_verification_error(error, address_hash_string, conn),
              :on_demand
            )
        end

      {:error, %{"error" => error}} ->
        EventsPublisher.broadcast(
          prepare_verification_error(error, address_hash_string, conn),
          :on_demand
        )
    end
  end

  def get_metadata_and_publish(address_hash_string, nil) do
    case Sourcify.get_metadata(address_hash_string) do
      {:ok, verification_metadata} ->
        process_metadata_and_publish(address_hash_string, verification_metadata, false)

      {:error, %{"error" => error}} ->
        {:error, error: error}
    end
  end

  def get_metadata_and_publish(address_hash_string, conn) do
    case Sourcify.get_metadata(address_hash_string) do
      {:ok, verification_metadata} ->
        process_metadata_and_publish(address_hash_string, verification_metadata, false, conn)

      {:error, %{"error" => error}} ->
        EventsPublisher.broadcast(
          prepare_verification_error(error, address_hash_string, conn),
          :on_demand
        )
    end
  end

  defp process_metadata_and_publish(address_hash_string, verification_metadata, is_partial, conn \\ nil) do
    %{"params_to_publish" => params_to_publish, "abi" => abi, "secondary_sources" => secondary_sources} =
      parse_params_from_sourcify(address_hash_string, verification_metadata)

    ContractController.publish(conn, %{
      "addressHash" => address_hash_string,
      "params" => Map.put(params_to_publish, "partially_verified", is_partial),
      "abi" => abi,
      "secondarySources" => secondary_sources
    })
  end

  def prepare_files_array(files) do
    if is_map(files), do: Enum.map(files, fn {_, file} -> file end), else: []
  end

  defp prepare_verification_error(msg, address_hash_string, conn) do
    [
      {:contract_verification_result,
       {address_hash_string,
        {:error,
         %Changeset{
           action: :insert,
           errors: [
             file: {msg, []}
           ],
           data: %SmartContract{},
           valid?: false
         }}, conn}}
    ]
  end

  def parse_params_from_sourcify(address_hash_string, verification_metadata) do
    [verification_metadata_json] =
      verification_metadata
      |> Enum.filter(&(Map.get(&1, "name") == "metadata.json"))

    full_params_initial = parse_json_from_sourcify_for_insertion(verification_metadata_json)

    verification_metadata_sol =
      verification_metadata
      |> Enum.filter(fn %{"name" => name, "content" => _content} -> name =~ ".sol" end)

    verification_metadata_sol
    |> Enum.reduce(full_params_initial, fn %{"name" => name, "content" => content, "path" => _path} = param,
                                           full_params_acc ->
      compilation_target_file_name = Map.get(full_params_acc, "compilation_target_file_name")

      if String.downcase(name) == String.downcase(compilation_target_file_name) do
        %{
          "params_to_publish" => extract_primary_source_code(content, Map.get(full_params_acc, "params_to_publish")),
          "abi" => Map.get(full_params_acc, "abi"),
          "secondary_sources" => Map.get(full_params_acc, "secondary_sources"),
          "compilation_target_file_name" => Map.get(full_params_acc, "compilation_target_file_name")
        }
      else
        secondary_sources = [
          prepare_additional_source(address_hash_string, param) | Map.get(full_params_acc, "secondary_sources")
        ]

        %{
          "params_to_publish" => Map.get(full_params_acc, "params_to_publish"),
          "abi" => Map.get(full_params_acc, "abi"),
          "secondary_sources" => secondary_sources,
          "compilation_target_file_name" => Map.get(full_params_acc, "compilation_target_file_name")
        }
      end
    end)
  end

  defp prepare_additional_source(address_hash_string, %{"name" => name, "content" => content, "path" => _path}) do
    %{
      "address_hash" => address_hash_string,
      "file_name" => name,
      "contract_source_code" => content
    }
  end

  defp extract_primary_source_code(content, params) do
    params
    |> Map.put("contract_source_code", content)
  end

  def parse_json_from_sourcify_for_insertion(verification_metadata_json) do
    %{"name" => _, "content" => content} = verification_metadata_json
    content_json = Sourcify.decode_json(content)
    compiler_version = "v" <> (content_json |> Map.get("compiler") |> Map.get("version"))
    abi = content_json |> Map.get("output") |> Map.get("abi")
    settings = Map.get(content_json, "settings")
    compilation_target_file_path = settings |> Map.get("compilationTarget") |> Map.keys() |> Enum.at(0)
    compilation_target_file_name = compilation_target_file_path |> String.split("/") |> Enum.at(-1)
    contract_name = settings |> Map.get("compilationTarget") |> Map.get("#{compilation_target_file_path}")
    optimizer = Map.get(settings, "optimizer")

    params =
      %{}
      |> Map.put("name", contract_name)
      |> Map.put("compiler_version", compiler_version)
      |> Map.put("evm_version", Map.get(settings, "evmVersion"))
      |> Map.put("optimization", Map.get(optimizer, "enabled"))
      |> Map.put("optimization_runs", Map.get(optimizer, "runs"))
      |> Map.put("external_libraries", Map.get(settings, "libraries"))
      |> Map.put("verified_via_sourcify", true)

    %{
      "params_to_publish" => params,
      "abi" => abi,
      "compilation_target_file_name" => compilation_target_file_name,
      "secondary_sources" => []
    }
  end

  def parse_optimization_runs(%{"runs" => runs}) do
    case Integer.parse(runs) do
      {integer, ""} -> integer
      _ -> 200
    end
  end

  def check_and_verify(address_hash_string) do
    if Chain.smart_contract_fully_verified?(address_hash_string) do
      {:ok, :already_fully_verified}
    else
      if Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Sourcify)[:enabled] do
        if Chain.smart_contract_verified?(address_hash_string) do
          case Sourcify.check_by_address(address_hash_string) do
            {:ok, _verified_status} ->
              get_metadata_and_publish(address_hash_string, nil)

            _ ->
              {:error, :not_verified}
          end
        else
          case Sourcify.check_by_address_any(address_hash_string) do
            {:ok, "full", metadata} ->
              process_metadata_and_publish(address_hash_string, metadata, false)

            {:ok, "partial", metadata} ->
              process_metadata_and_publish(address_hash_string, metadata, true)

            _ ->
              {:error, :not_verified}
          end
        end
      else
        {:error, :sourcify_disabled}
      end
    end
  end
end
