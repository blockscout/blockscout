defmodule BlockScoutWeb.API.V1.DecompiledSmartContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Hash.Address

  def create(conn, params) do
    if auth_token(conn) == actual_token() do
      with {:ok, hash} <- validate_address_hash(params["address_hash"]),
           :ok <- Chain.check_address_exists(hash),
           {:contract, :not_found} <-
             {:contract, Chain.check_decompiled_contract_exists(params["address_hash"], params["decompiler_version"])} do
        case Chain.create_decompiled_smart_contract(params) do
          {:ok, decompiled_smart_contract} ->
            send_resp(conn, :created, encode(decompiled_smart_contract))

          {:error, changeset} ->
            errors = parse_changeset_errors(changeset)

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
            encode(%{error: "decompiled code already exists for the decompiler version"})
          )
      end
    else
      send_resp(conn, :forbidden, "")
    end
  end

  defp parse_changeset_errors(changeset) do
    changeset.errors
    |> Enum.into(%{}, fn {field, {message, _}} ->
      {field, message}
    end)
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
