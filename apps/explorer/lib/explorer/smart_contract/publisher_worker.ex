defmodule Explorer.SmartContract.PublisherWorker do
  use Que.Worker

  alias Explorer.SmartContract.Publisher

  def perform({address_hash, params, external_libraries}) do
    case Publisher.publish(address_hash, params, external_libraries) do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        errors =
          changeset.errors
          |> Enum.into(%{}, fn {field, {message, _}} ->
            {field, message}
          end)

        {:error, errors}
    end
  end
end
