defmodule Explorer.SmartContract.PublisherWorker do
  @moduledoc """
  Background smart contract verification worker.
  """

  use Que.Worker, concurrency: 5

  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.SmartContract.Publisher

  def perform({address_hash, params, external_libraries}) do
    result =
      case Publisher.publish(address_hash, params, external_libraries) do
        {:ok, _contract} = result ->
          result

        {:error, changeset} ->
          {:error, changeset}
      end

    EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result}}], :on_demand)
  end
end
