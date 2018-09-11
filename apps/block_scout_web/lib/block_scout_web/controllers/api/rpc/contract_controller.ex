defmodule BlockScoutWeb.API.RPC.ContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def getabi(conn, params) do
    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:contract, {:ok, contract}} <- to_smart_contract(address_hash) do
      render(conn, :getabi, %{abi: contract.abi})
    else
      {:address_param, :error} ->
        render(conn, :error, error: "Query parameter address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid address hash")

      {:contract, :not_found} ->
        render(conn, :error, error: "Contract source code not verified")
    end
  end

  defp fetch_address(params) do
    {:address_param, Map.fetch(params, "address")}
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end

  defp to_smart_contract(address_hash) do
    result =
      case Chain.address_hash_to_smart_contract(address_hash) do
        nil -> :not_found
        contract -> {:ok, contract}
      end

    {:contract, result}
  end
end
