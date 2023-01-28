defmodule Explorer.SmartContract.Vyper.PublisherWorker do
  @moduledoc """
  Background smart contract verification worker.
  """

  use Que.Worker, concurrency: 5

  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.SmartContract.Vyper.Publisher

  def perform({address_hash, params, %Plug.Conn{} = conn}) do
    broadcast(address_hash, [address_hash, params], conn)
  end

  def perform({address_hash, params, files}) do
    broadcast(address_hash, [address_hash, params, files])
  end

  def perform({address_hash, params}) do
    broadcast(address_hash, [address_hash, params])
  end

  defp broadcast(address_hash, args, conn \\ nil) do
    result =
      case apply(Publisher, :publish, args) do
        {:ok, _contract} = result ->
          result

        {:error, changeset} ->
          {:error, changeset}
      end

    if conn do
      EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result, conn}}], :on_demand)
    else
      EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result}}], :on_demand)
    end
  end
end
