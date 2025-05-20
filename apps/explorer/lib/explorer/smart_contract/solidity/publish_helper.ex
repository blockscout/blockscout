defmodule Explorer.SmartContract.Solidity.PublishHelper do
  @moduledoc """
    Module responsible for preparing and publishing smart contracts
  """

  use Utils.RuntimeEnvHelper,
    eth_bytecode_db_enabled?: [
      :explorer,
      [
        Explorer.SmartContract.RustVerifierInterfaceBehaviour,
        :eth_bytecode_db?
      ]
    ],
    sourcify_enabled?: [
      :explorer,
      [
        Explorer.ThirdPartyIntegrations.Sourcify,
        :enabled
      ]
    ]

  alias Ecto.Changeset
  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Solidity.Publisher
  alias Explorer.ThirdPartyIntegrations.Sourcify

  def verify_and_publish(address_hash_string, files_array, conn, api_v2?, chosen_contract \\ nil) do
    with {:ok, _verified_status} <- Sourcify.verify(address_hash_string, files_array, chosen_contract),
         {:ok, _verified_status} <- Sourcify.check_by_address(address_hash_string) do
      get_metadata_and_publish(address_hash_string, conn, api_v2?)
    else
      {:error, "partial"} ->
        {:ok, status, metadata} = Sourcify.check_by_address_any(address_hash_string)
        process_metadata_and_publish(address_hash_string, metadata, status == "partial", conn, api_v2?)

      {:error, %{"error" => error}} ->
        EventsPublisher.broadcast(
          prepare_verification_error(error, address_hash_string, conn, api_v2?),
          :on_demand
        )

      {:error, error} ->
        EventsPublisher.broadcast(
          prepare_verification_error(error, address_hash_string, conn, api_v2?),
          :on_demand
        )

      _ ->
        EventsPublisher.broadcast(
          prepare_verification_error("Unexpected error", address_hash_string, conn, api_v2?),
          :on_demand
        )
    end
  end

  def get_metadata_and_publish(address_hash_string, conn, api_v2? \\ false) do
    case Sourcify.get_metadata(address_hash_string) do
      {:ok, verification_metadata} ->
        process_metadata_and_publish(address_hash_string, verification_metadata, false, conn, api_v2?)

      {:error, %{"error" => error}} ->
        return_sourcify_error(conn, error, address_hash_string, api_v2?)
    end
  end

  defp process_metadata_and_publish(address_hash_string, verification_metadata, is_partial, conn \\ nil, api_v2?) do
    case Sourcify.parse_params_from_sourcify(address_hash_string, verification_metadata) do
      %{
        "params_to_publish" => params_to_publish,
        "abi" => abi,
        "secondary_sources" => secondary_sources,
        "compilation_target_file_path" => compilation_target_file_path
      } ->
        publish(
          conn,
          %{
            "addressHash" => address_hash_string,
            "params" => Map.put(params_to_publish, "partially_verified", is_partial),
            "abi" => abi,
            "secondarySources" => secondary_sources,
            "compilationTargetFilePath" => compilation_target_file_path
          },
          api_v2?
        )

      {:error, :metadata} ->
        return_sourcify_error(conn, Sourcify.no_metadata_message(), address_hash_string, api_v2?)

      _ ->
        return_sourcify_error(conn, Sourcify.failed_verification_message(), address_hash_string, api_v2?)
    end
  end

  defp return_sourcify_error(nil, error, _address_hash_string, _api_v2?) do
    {:error, error: error}
  end

  defp return_sourcify_error(conn, error, address_hash_string, api_v2?) do
    EventsPublisher.broadcast(
      prepare_verification_error(error, address_hash_string, conn, api_v2?),
      :on_demand
    )
  end

  def prepare_files_array(files) when is_map(files), do: Map.values(files)

  def prepare_files_array(_), do: []

  def get_one_json(files_array) do
    files_array
    |> Enum.filter(fn file ->
      case file do
        %Plug.Upload{content_type: content_type} ->
          content_type == "application/json"

        _ ->
          false
      end
    end)
    |> Enum.at(0)
  end

  # sobelow_skip ["Traversal.FileModule"]
  def read_files(plug_uploads) do
    Enum.reduce(plug_uploads, %{}, fn file, acc ->
      case file do
        %Plug.Upload{path: path, filename: file_name} ->
          {:ok, file_content} = File.read(path)
          Map.put(acc, file_name, file_content)

        _ ->
          acc
      end
    end)
  end

  def prepare_verification_error(msg, address_hash_string, conn, api_v2? \\ false)

  def prepare_verification_error(msg, address_hash_string, conn, false) do
    [
      {:contract_verification_result,
       {address_hash_string,
        {:error,
         %Changeset{
           action: :insert,
           errors: [
             files: {msg, []}
           ],
           data: %SmartContract{address_hash: address_hash_string},
           valid?: false
         }}, conn}}
    ]
  end

  def prepare_verification_error(msg, address_hash_string, _conn, true) do
    changeset =
      SmartContract.invalid_contract_changeset(%SmartContract{address_hash: address_hash_string}, %{}, msg, nil, true)

    [
      {:contract_verification_result, {address_hash_string, {:error, changeset}}}
    ]
  end

  def check_and_verify(address_hash_string, options \\ []) do
    cond do
      eth_bytecode_db_enabled?() ->
        LookUpSmartContractSourcesOnDemand.trigger_fetch(options[:ip], address_hash_string)

      sourcify_enabled?() ->
        address_hash_string
        |> SmartContract.select_partially_verified_by_address_hash()
        |> check_by_address_in_sourcify(address_hash_string)

      true ->
        {:error, :sourcify_disabled}
    end
  end

  def sourcify_check(address_hash_string) do
    cond do
      eth_bytecode_db_enabled?() ->
        {:error, :eth_bytecode_db_enabled}

      sourcify_enabled?() ->
        check_by_address_in_sourcify(
          SmartContract.select_partially_verified_by_address_hash(address_hash_string),
          address_hash_string
        )

      true ->
        {:error, :sourcify_disabled}
    end
  end

  defp check_by_address_in_sourcify(false, _address_hash_string) do
    {:ok, :already_fully_verified}
  end

  defp check_by_address_in_sourcify(true, address_hash_string) do
    case Sourcify.check_by_address(address_hash_string) do
      {:ok, _verified_status} ->
        get_metadata_and_publish(address_hash_string, nil)

      _ ->
        {:error, :not_verified}
    end
  end

  defp check_by_address_in_sourcify(nil, address_hash_string) do
    case Sourcify.check_by_address_any(address_hash_string) do
      {:ok, "full", metadata} ->
        process_metadata_and_publish(address_hash_string, metadata, false, false)

      {:ok, "partial", metadata} ->
        process_metadata_and_publish(address_hash_string, metadata, true, false)

      _ ->
        {:error, :not_verified}
    end
  end

  def publish_without_broadcast(
        %{"addressHash" => address_hash, "abi" => abi, "compilationTargetFilePath" => file_path} = input
      ) do
    params = process_params(input)

    address_hash
    |> Publisher.publish_smart_contract(params, abi, true, file_path)
    |> process_response()
  end

  def publish_without_broadcast(%{"addressHash" => address_hash, "abi" => abi} = input) do
    params = process_params(input)

    address_hash
    |> Publisher.publish_smart_contract(params, abi, false)
    |> process_response()
  end

  def publish(nil, %{"addressHash" => _address_hash} = input, _) do
    publish_without_broadcast(input)
  end

  def publish(conn, %{"addressHash" => address_hash} = input, api_v2?) do
    result = publish_without_broadcast(input)

    if api_v2? do
      EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result}}], :on_demand)
    else
      EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result, conn}}], :on_demand)
    end
  end

  def process_params(input) do
    if Map.has_key?(input, "secondarySources") do
      input["params"]
      |> Map.put("secondary_sources", Map.get(input, "secondarySources"))
    else
      input["params"]
    end
  end

  def process_response(response) do
    case response do
      {:ok, _contract} = result ->
        result

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
