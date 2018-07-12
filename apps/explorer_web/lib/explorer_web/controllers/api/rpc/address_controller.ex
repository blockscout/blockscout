defmodule ExplorerWeb.API.RPC.AddressController do
  use ExplorerWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Wei}

  def balance(conn, params) do
    with {:address_param, {:ok, address_hash_string}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_hash_string),
         {:ok, address} <- hash_to_address(address_hash) do
      render(conn, :balance, %{address: address})
    else
      {:address_param, :error} ->
        conn
        |> put_status(400)
        |> render(:error, error: "Query parameter 'address' is required")

      {:format, :error} ->
        conn
        |> put_status(400)
        |> render(:error, error: "Invalid address hash")
    end
  end

  defp fetch_address(params) do
    {:address_param, Map.fetch(params, "address")}
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end

  defp hash_to_address(address_hash) do
    address =
      case Chain.hash_to_address(address_hash) do
        {:ok, address} -> address
        {:error, :not_found} -> %Address{fetched_balance: %Wei{value: 0}}
      end

    {:ok, address}
  end
end
