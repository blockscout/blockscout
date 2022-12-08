defmodule Explorer.SmartContract.Solidity.PublisherWorker do
  @moduledoc """
  Background smart contract verification worker.
  """

  use Que.Worker, concurrency: 5

  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.Chain.SmartContract.VerificationStatus
  alias Explorer.SmartContract.Solidity.Publisher

  def perform({"flattened", %{"address_hash" => address_hash} = params, external_libraries, conn}) do
    result =
      case Publisher.publish(address_hash, params, external_libraries) do
        {:ok, _contract} = result ->
          result

        {:error, changeset} ->
          {:error, changeset}
      end

    EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result, conn}}], :on_demand)
  end

  def perform({"multipart", %{"address_hash" => address_hash} = params, files_map, external_libraries, conn})
      when is_map(files_map) do
    result =
      case Publisher.publish_with_multi_part_files(params, external_libraries, files_map) do
        {:ok, _contract} = result ->
          result

        {:error, changeset} ->
          {:error, changeset}
      end

    EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result, conn}}], :on_demand)
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

  def perform({"json_web", %{"address_hash" => address_hash} = params, json_input, conn}) do
    result =
      case Publisher.publish_with_standard_json_input(params, json_input) do
        {:ok, _contract} = result ->
          result

        {:error, changeset} ->
          {:error, changeset}
      end

    EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result, conn}}], :on_demand)
  end
end
