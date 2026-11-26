# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.SmartContract.Solidity.PublisherWorker do
  @moduledoc """
  Background smart contract verification worker.
  """

  require Logger

  use Que.Worker, concurrency: 5

  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.SmartContract.VerificationStatus
  alias Explorer.SmartContract.Helper
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

  # See `broadcast/4` on skipping contracts already verified with a full match.
  def perform({"sourcify_api_v2", address_hash_string, files_array, conn, chosen_contract}) do
    if SmartContract.verified_with_full_match?(address_hash_string) do
      broadcast_result(address_hash_string, {:ok, nil}, nil)
    else
      case Sourcify.check_by_address(address_hash_string) do
        {:ok, _verified_status} ->
          PublishHelper.get_metadata_and_publish(address_hash_string, conn, true)

        _ ->
          PublishHelper.verify_and_publish(address_hash_string, files_array, conn, true, chosen_contract)
      end
    end
  end

  def perform({"json_api", %{"address_hash" => address_hash} = params, json_input, uid}) when is_binary(uid) do
    publish_and_update_status(:publish_with_standard_json_input, [params, json_input], address_hash, uid)
  end

  def perform({"flattened_api", %{"address_hash" => address_hash} = params, external_libraries, uid})
      when is_binary(uid) do
    publish_and_update_status(:publish, [address_hash, params, external_libraries], address_hash, uid)
  end

  # Called by Que when `perform/1` crashed: report the failure, otherwise the RPC status
  # stays pending and the UI keeps waiting for the verification result forever.
  # The result is broadcast without `conn`: the old UI is deprecated, its channel drops
  # such a result, so its form keeps waiting, as before.
  def on_failure({type, %{"address_hash" => address_hash}, _input, uid}, error)
      when type in ["json_api", "flattened_api"] do
    log_crash(address_hash, error)
    VerificationStatus.set_failed_if_pending(uid, address_hash)
  end

  def on_failure({type, %{"address_hash" => address_hash}, _input, _conn}, error)
      when type in ["flattened", "json_web"] do
    broadcast_crash(address_hash, error)
  end

  def on_failure({"multipart", %{"address_hash" => address_hash}, _files_map, _external_libraries, _conn}, error) do
    broadcast_crash(address_hash, error)
  end

  def on_failure({"flattened_api_v2", %{"address_hash" => address_hash}}, error) do
    broadcast_crash(address_hash, error)
  end

  def on_failure({type, %{"address_hash" => address_hash}, _input}, error)
      when type in ["json_api_v2", "multipart_api_v2"] do
    broadcast_crash(address_hash, error)
  end

  def on_failure({"sourcify_api_v2", address_hash_string, _files_array, _conn, _chosen_contract}, error) do
    broadcast_crash(address_hash_string, error)
  end

  # Defining `on_failure/2` replaces the default no-op one, so the jobs of other shapes
  # (e.g. an empty old UI request) must not crash here: there is no result to report.
  def on_failure(_args, error) do
    Logger.error("Solidity smart-contract verification crashed: #{inspect(error)}")
  end

  # A contract verified with a full match can't be re-verified: such requests are rejected
  # when accepted, but the job could be queued before the contract got verified via another
  # path (e.g. automatically via eth_bytecode_db). Then the verifier is not called at all.
  # The result carries no contract: its consumers check only the result tag.
  defp broadcast(method, address_hash, args, conn \\ nil) do
    result =
      if SmartContract.verified_with_full_match?(address_hash) do
        {:ok, nil}
      else
        case apply(Publisher, method, args) do
          {:ok, _contract} = result ->
            result

          {:error, changeset} ->
            Logger.error(
              "Solidity smart-contract verification #{address_hash} failed because of the error: #{inspect(changeset)}"
            )

            {:error, changeset}
        end
      end

    broadcast_result(address_hash, result, conn)
  end

  defp broadcast_crash(address_hash, error) do
    log_crash(address_hash, error)
    broadcast_result(address_hash, {:error, Helper.verification_crash_changeset(address_hash)}, nil)
  end

  defp log_crash(address_hash, error) do
    Logger.error("Solidity smart-contract verification #{address_hash} crashed: #{inspect(error)}")
  end

  defp broadcast_result(address_hash, result, conn) do
    Logger.info("Smart-contract #{address_hash} verification: broadcast verification results")

    if conn do
      EventsPublisher.broadcast(
        [{:contract_verification_result, {String.downcase(address_hash), result, conn}}],
        :on_demand
      )
    else
      EventsPublisher.broadcast([{:contract_verification_result, {String.downcase(address_hash), result}}], :on_demand)
    end
  end

  # The pending attempt is registered before the full match check: a full match committed
  # after the check then marks it as passed (see
  # `VerificationStatus.set_pending_statuses_to_passed/1`). An attempt sharing the uid with
  # an earlier one is not verified (see `VerificationStatus.insert_pending_status/2`).
  defp publish_and_update_status(method, args, address_hash, uid) do
    with :ok <- VerificationStatus.insert_pending_status(uid, address_hash) do
      do_publish_and_update_status(method, args, address_hash, uid)
    end
  end

  # See `broadcast/4` on skipping contracts already verified with a full match.
  defp do_publish_and_update_status(method, args, address_hash, uid) do
    if SmartContract.verified_with_full_match?(address_hash) do
      VerificationStatus.update_status(uid, :pass)
    else
      case apply(Publisher, method, args) do
        {:ok, _contract} ->
          VerificationStatus.update_status(uid, :pass)

        # The status may already be passed if the contract got verified via another path
        # meanwhile (see `VerificationStatus.set_pending_statuses_to_passed/1`).
        {:error, _changeset} ->
          VerificationStatus.set_failed_if_pending(uid, address_hash)
      end
    end
  end
end
