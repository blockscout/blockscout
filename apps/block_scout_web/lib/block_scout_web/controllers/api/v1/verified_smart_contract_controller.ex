defmodule BlockScoutWeb.API.V1.VerifiedSmartContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Hash.Address
  alias Explorer.SmartContract.PublisherWorker

  def create(conn, params) do
    with {:ok, hash} <- validate_address_hash(params["address_hash"]),
         :ok <- smart_contract_exists?(hash),
         :ok <- verified_smart_contract_exists?(hash) do
      external_libraries = fetch_external_libraries(params) || %{}

      PublisherWorker.perform({hash, params, external_libraries})

      send_resp(conn, :created, Jason.encode!(%{status: :started_processing}))
    end
  end

  defp smart_contract_exists?(address_hash) do
    case Chain.hash_to_address(address_hash) do
      {:ok, _address} -> :ok
      _ -> :not_found
    end
  end

  defp validate_address_hash(address_hash) do
    case Address.cast(address_hash) do
      {:ok, hash} -> {:ok, hash}
      :error -> :invalid_address
    end
  end

  defp verified_smart_contract_exists?(address_hash) do
    if Chain.address_hash_to_smart_contract(address_hash) do
      :contract_exists
    else
      :ok
    end
  end

  defp fetch_external_libraries(params) do
    keys = Enum.flat_map(1..5, fn i -> ["library#{i}_name", "library#{i}_address"] end)

    Map.take(params, keys)
  end
end
