defmodule Explorer.SmartContract.Solidity.PublisherWorker do
  @moduledoc """
  Background smart contract verification worker.
  """

  require Logger

  use Que.Worker, concurrency: 5

  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.Chain.SmartContract.VerificationStatus
  alias Explorer.SmartContract.Solidity.{Publisher, PublishHelper}
  alias Explorer.ThirdPartyIntegrations.Sourcify

  def perform({"flattened", %{"address_hash" => address_hash} = params, external_libraries, conn}) do
    broadcast(:publish, address_hash, [address_hash, params, external_libraries], conn)
  end

  def perform({"multipart", %{"address_hash" => address_hash} = params, files_map, external_libraries, conn})
      when is_map(files_map) do
    broadcast(:publish_with_multi_part_files, address_hash, [params, external_libraries, files_map], conn)
  end

  def perform({"json_web", %{"address_hash" => address_hash} = params, json_input, conn}) do
    broadcast(:publish_with_standard_json_input, address_hash, [params, json_input], conn)
  end

  def perform({"flattened_api_v2", %{"address_hash" => address_hash} = params}) do
    broadcast(:publish, address_hash, [address_hash, params])
  end

  def perform({"json_api_v2", %{"address_hash" => address_hash} = params, json_input}) do
    broadcast(:publish_with_standard_json_input, address_hash, [params, json_input])
  end

  def perform({"multipart_api_v2", %{"address_hash" => address_hash} = params, files_map})
      when is_map(files_map) do
    broadcast(:publish_with_multi_part_files, address_hash, [params, files_map])
  end

  def perform({"sourcify_api_v2", address_hash_string, files_array, conn, chosen_contract}) do
    case Sourcify.check_by_address(address_hash_string) do
      {:ok, _verified_status} ->
        PublishHelper.get_metadata_and_publish(address_hash_string, conn, true)

      _ ->
        PublishHelper.verify_and_publish(address_hash_string, files_array, conn, true, chosen_contract)
    end
  end

  def perform({"json_api", %{"address_hash" => address_hash} = params, json_input, uid}) when is_binary(uid) do
    VerificationStatus.insert_status(uid, :pending, address_hash)

    case Publisher.publish_with_standard_json_input(params, json_input) do
      {:ok, _contract} ->
        VerificationStatus.update_status(uid, :pass)

      {:error, _changeset} ->
        VerificationStatus.update_status(uid, :fail)
    end
  end

  defp broadcast(method, address_hash, args, conn \\ nil) do
    result =
      case apply(Publisher, method, args) do
        {:ok, _contract} = result ->
          result

        {:error, changeset} ->
          {:error, changeset}
      end

    Logger.info("Smart-contract #{address_hash} verification: broadcast verification results")

    if conn do
      EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result, conn}}], :on_demand)
    else
      EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result}}], :on_demand)
    end
  end
end
