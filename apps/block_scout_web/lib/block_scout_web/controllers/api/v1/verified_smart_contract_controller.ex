defmodule BlockScoutWeb.API.V1.VerifiedSmartContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Hash.Address
  alias Explorer.SmartContract.Solidity.Publisher

  def create(conn, params) do
    with {:ok, hash} <- validate_address_hash(params["address_hash"]),
         :ok <- Chain.check_address_exists(hash),
         {:contract, :not_found} <- {:contract, Chain.check_verified_smart_contract_exists(hash)} do
      external_libraries = fetch_external_libraries(params)

      case Publisher.publish(hash, params, external_libraries) do
        {:ok, _} ->
          send_resp(conn, :created, encode(%{status: :success}))

        {:error, changeset} ->
          errors =
            changeset.errors
            |> Enum.into(%{}, fn {field, {message, _}} ->
              {field, message}
            end)

          send_resp(conn, :unprocessable_entity, encode(errors))
      end
    else
      :invalid_address ->
        send_resp(conn, :unprocessable_entity, encode(%{error: "address_hash is invalid"}))

      :not_found ->
        send_resp(conn, :unprocessable_entity, encode(%{error: "address is not found"}))

      {:contract, :ok} ->
        send_resp(
          conn,
          :unprocessable_entity,
          encode(%{error: "verified code already exists for this address"})
        )
    end
  end

  defp validate_address_hash(address_hash) do
    case Address.cast(address_hash) do
      {:ok, hash} -> {:ok, hash}
      :error -> :invalid_address
    end
  end

  defp encode(data) do
    Jason.encode!(data)
  end

  defp fetch_external_libraries(params) do
    keys = Enum.flat_map(1..10, fn i -> ["library#{i}_name", "library#{i}_address"] end)

    Map.take(params, keys)
  end
end
