defmodule BlockScoutWeb.AddressContractVerificationViaJsonController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.RPC.ContractController
  alias BlockScoutWeb.Controller
  alias Ecto.Changeset
  alias Explorer.Chain
  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Solidity.PublisherWorker, as: SolidityPublisherWorker
  alias Explorer.ThirdPartyIntegrations.Sourcify

  def new(conn, %{"address_id" => address_hash_string}) do
    address_path =
      conn
      |> address_path(:show, address_hash_string)
      |> Controller.full_path()

    if Chain.smart_contract_fully_verified?(address_hash_string) do
      redirect(conn, to: address_path)
    else
      case Sourcify.check_by_address(address_hash_string) do
        {:ok, _verified_status} ->
          case get_metadata_and_publish(address_hash_string, conn) do
            :update_submitted ->
              conn
              |> render("submitted.html", address_string: address_hash_string, path: address_path)

            _ ->
              redirect(conn, to: address_path)
          end

        _ ->
          changeset =
            SmartContract.changeset(
              %SmartContract{address_hash: address_hash_string},
              %{}
            )

          render(conn, "new.html", changeset: changeset, address_hash: address_hash_string)
      end
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
            "This contract is already verified.",
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
    with {:ok, _verified_status} <- Sourcify.verify(address_hash_string, files_array),
         {:ok, _verified_status} <- Sourcify.check_by_address(address_hash_string) do
      get_metadata_and_publish(address_hash_string, conn)
    else
      {:error, "partial"} ->
        {:ok, status, metadata} = Sourcify.check_by_address_any(address_hash_string)
        process_metadata_and_publish(address_hash_string, metadata, status == "partial", conn)

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

      {:error, :timeout} ->
        {:error, error: :timeout}
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
    %{
      "params_to_publish" => params_to_publish,
      "abi" => abi,
      "secondary_sources" => secondary_sources,
      "compilation_target_file_path" => compilation_target_file_path
    } = Sourcify.parse_params_from_sourcify(address_hash_string, verification_metadata)

    ContractController.publish(conn, %{
      "addressHash" => address_hash_string,
      "params" => Map.put(params_to_publish, "partially_verified", is_partial),
      "abi" => abi,
      "secondarySources" => secondary_sources,
      "compilationTargetFilePath" => compilation_target_file_path
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
