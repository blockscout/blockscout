defmodule BlockScoutWeb.API.V1.DecompiledSmartContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Hash.Address

  def create(conn, params) do
    if auth_token(conn) == actual_token() do
      with {:ok, hash} <- validate_address_hash(params["address_hash"]),
           :ok <- smart_contract_exists?(hash) do
        case Chain.create_decompiled_smart_contract(params) do
          {:ok, decompiled_smart_contract} ->
            send_resp(conn, :created, Jason.encode!(decompiled_smart_contract))

          {:error, changeset} ->
            errors =
              changeset.errors
              |> Enum.into(%{}, fn {field, {message, _}} ->
                {field, message}
              end)

            send_resp(conn, :unprocessable_entity, encode(errors))
        end
      else
        :invalid_address -> send_resp(conn, :unprocessable_entity, encode(%{error: "address_hash is invalid"}))
        :not_found -> send_resp(conn, :unprocessable_entity, encode(%{error: "address is not found"}))
      end
    else
      send_resp(conn, :forbidden, "")
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

  defp auth_token(conn) do
    case get_req_header(conn, "auth_token") do
      [token] -> token
      other -> other
    end
  end

  defp actual_token do
    Application.get_env(:block_scout_web, :decompiled_smart_contract_token)
  end

  defp encode(data) do
    Jason.encode!(data)
  end
end
