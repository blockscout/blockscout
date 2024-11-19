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
  @spec broadcast(atom(), binary() | Explorer.Chain.Hash.t(), any()) :: any()
  defp broadcast(method, address_hash, args) do
    result =
      case apply(Publisher, method, args) do
        {:ok, _contract} = result ->
          result

        {:error, changeset} ->
          Logger.error(
            "Stylus smart-contract verification #{address_hash} failed because of the error: #{inspect(changeset)}"
          )

          {:error, changeset}
      end

    Logger.info("Smart-contract #{address_hash} verification: broadcast verification results")

    EventsPublisher.broadcast([{:contract_verification_result, {String.downcase(address_hash), result}}], :on_demand)
  end
end
