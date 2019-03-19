defmodule BlockScoutWeb.API.V1.DecompiledSmartContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def create(conn, params) do
    if auth_token(conn) == actual_token() do
      case Chain.create_decompiled_smart_contract(params) do
        {:ok, _decompiled_source_code} ->
          put_status(conn, :created)

        {:error, _changeset} ->
          put_status(conn, :unprocessable_entity)
      end
    else
      put_status(conn, :forbidden)
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
