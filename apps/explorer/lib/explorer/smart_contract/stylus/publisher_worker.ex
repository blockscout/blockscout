defmodule Explorer.SmartContract.Stylus.PublisherWorker do
  @moduledoc """
  Background smart contract verification worker.
  """

  require Logger

  use Que.Worker, concurrency: 5

  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.SmartContract.Stylus.Publisher

  def perform({"github_repository", %{"address_hash" => address_hash} = params}) do
    broadcast(:publish, address_hash, [address_hash, params])
  end

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
