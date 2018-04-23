defmodule ExplorerWeb.AddressController do
  use ExplorerWeb, :controller

  alias Explorer.Chain

  def show(conn, %{"id" => string}) do
    with {:ok, hash} <- Chain.string_to_address_hash(string),
         {:ok, address} <- Chain.hash_to_address(hash) do
      render(conn, "show.html", address: address)
    else
      :error -> not_found(conn)
      {:error, :not_found} -> not_found(conn)
    end
  end
end
