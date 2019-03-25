defmodule BlockScoutWeb.API.V1.DecompiledSmartContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Hash.Address

  def create(conn, params) do
    if auth_token(conn) == actual_token() do
      with :ok <- validate_address_hash(params["address_hash"]) do
        case Chain.create_decompiled_smart_contract(params) do
          {:ok, _decompiled_source_code} ->
            send_resp(conn, :created, "ok")

          {:error, _changeset} ->
            send_resp(conn, :unprocessable_entity, "error")
        end
      else
        :error -> send_resp(conn, :unprocessable_entity, "error")
      end
    else
      send_resp(conn, :forbidden, "")
    end
  end

  defp validate_address_hash(address_hash) do
    case Address.cast(address_hash) do
      {:ok, _} -> :ok
      :error -> :error
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
end
