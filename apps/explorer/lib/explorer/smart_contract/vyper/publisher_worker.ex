defmodule Explorer.SmartContract.Vyper.PublisherWorker do
  @moduledoc """
  Background smart contract verification worker.
  """

  require Logger

  use Que.Worker, concurrency: 5

  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
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

  defp broadcast(address_hash, args, function, conn \\ nil) do
    result =
      case apply(Publisher, function, args) do
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
