# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.SmartContract.Vyper.PublisherWorker do
  @moduledoc """
  Background smart contract verification worker.
  """

  require Logger

  use Que.Worker, concurrency: 5

  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Helper
  alias Explorer.SmartContract.Vyper.Publisher

  def perform({"vyper_standard_json", params}) do
    broadcast(params["address_hash"], [params], :publish_standard_json)
  end

  def perform({"vyper_multipart", params, files}) do
    broadcast(params["address_hash"], [params["address_hash"], params, files], :publish)
  end

  def perform({"vyper_flattened", params}) do
    broadcast(params["address_hash"], [params["address_hash"], params], :publish)
  end

  def perform({address_hash, params, %Plug.Conn{} = conn}) do
    broadcast(address_hash, [address_hash, params], :publish, conn)
  end

  # Called by Que when `perform/1` crashed: report the failure, otherwise the UI keeps
  # waiting for the verification result forever. The result is broadcast without `conn`:
  # the old UI is deprecated, its channel drops such a result, so its form keeps waiting,
  # as before.
  def on_failure({type, params}, error) when type in ["vyper_standard_json", "vyper_flattened"] do
    broadcast_crash(params["address_hash"], error)
  end

  def on_failure({"vyper_multipart", params, _files}, error) do
    broadcast_crash(params["address_hash"], error)
  end

  def on_failure({address_hash, _params, %Plug.Conn{}}, error) do
    broadcast_crash(address_hash, error)
  end

  # Defining `on_failure/2` replaces the default no-op one, so the jobs of other shapes
  # must not crash here: there is no result to report.
  def on_failure(_args, error) do
    Logger.error("Vyper smart-contract verification crashed: #{inspect(error)}")
  end

  # A contract verified with a full match can't be re-verified: such requests are rejected
  # when accepted, but the job could be queued before the contract got verified via another
  # path (e.g. automatically via eth_bytecode_db). Then the verifier is not called at all.
  # The result carries no contract: its consumers check only the result tag.
  defp broadcast(address_hash, args, function, conn \\ nil) do
    result =
      if SmartContract.verified_with_full_match?(address_hash) do
        {:ok, nil}
      else
        case apply(Publisher, function, args) do
          {:ok, _contract} = result ->
            result

          {:error, changeset} ->
            {:error, changeset}
        end
      end

    broadcast_result(address_hash, result, conn)
  end

  defp broadcast_crash(address_hash, error) do
    Logger.error("Vyper smart-contract verification #{address_hash} crashed: #{inspect(error)}")
    broadcast_result(address_hash, {:error, Helper.verification_crash_changeset(address_hash)}, nil)
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
end
