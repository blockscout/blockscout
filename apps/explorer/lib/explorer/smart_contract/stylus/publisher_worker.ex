# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.SmartContract.Stylus.PublisherWorker do
  @moduledoc """
    Processes Stylus smart contract verification requests asynchronously in the background.

    This module implements a worker that handles verification of Stylus smart contracts
    through their GitHub repository source code. It uses a job queue system to:
    - Receive verification requests containing contract address and GitHub details
    - Delegate verification to the Publisher module
    - Broadcast verification results through the events system
  """

  require Logger

  use Que.Worker, concurrency: 5

  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Helper
  alias Explorer.SmartContract.Stylus.Publisher

  @doc """
    Processes a Stylus smart contract verification request.

    Initiates the verification process by broadcasting the verification request to
    the module responsible for the actual verification and consequent update of
    the database. This function is called automatically by the job queue system.

    ## Parameters
    - `{"github_repository", params}`: Tuple containing:
      - First element: `"github_repository"` indicating the verification source
      - Second element: Map containing:
        - `"address_hash"`: The contract's address hash to verify

    ## Returns
    - Result of the broadcast operation
  """
  @spec perform({binary(), %{String.t() => any()}}) :: any()
  def perform({"github_repository", %{"address_hash" => address_hash} = params}) do
    broadcast(:publish, address_hash, [address_hash, params])
  end

  @doc """
    Reports a failed verification when `perform/1` crashed.

    Called by the job queue system. Without it the UI keeps waiting for the
    verification result forever.

    ## Parameters
    - `args`: The job arguments, as passed to `perform/1`
    - `error`: The crash reason

    ## Returns
    - Result of the broadcast operation
  """
  @spec on_failure({binary(), %{String.t() => any()}}, any()) :: any()
  def on_failure({"github_repository", %{"address_hash" => address_hash}}, error) do
    Logger.error("Stylus smart-contract verification #{address_hash} crashed: #{inspect(error)}")
    broadcast_result(address_hash, {:error, Helper.verification_crash_changeset(address_hash)})
  end

  # Defining `on_failure/2` replaces the default no-op one, so the jobs of other shapes
  # must not crash here: there is no result to report.
  def on_failure(_args, error) do
    Logger.error("Stylus smart-contract verification crashed: #{inspect(error)}")
  end

  # Broadcasts the result of a Stylus smart contract verification attempt.
  #
  # Executes the specified verification method in the `Publisher` module and
  # broadcasts the result through the events publisher.
  #
  # ## Parameters
  # - `method`: The verification method to execute
  # - `address_hash`: Contract address
  # - `args`: Arguments to pass to the verification method
  #
  # ## Returns
  # - `{:ok, contract}` if verification succeeds
  # - `{:error, changeset}` if verification fails
  #
  # A contract verified with a full match can't be re-verified: such requests are rejected
  # when accepted, but the job could be queued before the contract got verified via another
  # request. Then the verifier is not called at all.
  # The result carries no contract: its consumers check only the result tag.
  @spec broadcast(atom(), binary() | Explorer.Chain.Hash.t(), any()) :: any()
  defp broadcast(method, address_hash, args) do
    result =
      if SmartContract.verified_with_full_match?(address_hash) do
        {:ok, nil}
      else
        case apply(Publisher, method, args) do
          {:ok, _contract} = result ->
            result

          {:error, changeset} ->
            Logger.error(
              "Stylus smart-contract verification #{address_hash} failed because of the error: #{inspect(changeset)}"
            )

            {:error, changeset}
        end
      end

    broadcast_result(address_hash, result)
  end

  defp broadcast_result(address_hash, result) do
    Logger.info("Smart-contract #{address_hash} verification: broadcast verification results")

    EventsPublisher.broadcast([{:contract_verification_result, {String.downcase(address_hash), result}}], :on_demand)
  end
end
