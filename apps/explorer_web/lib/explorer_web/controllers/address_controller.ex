defmodule ExplorerWeb.AddressController do
  use ExplorerWeb, :controller

  alias Explorer.Chain

  def show(conn, %{"id" => hash}) do
    hash
    |> Chain.hash_to_address()
    |> case do
      {:ok, address} -> render(conn, "show.html", address: address)
      {:error, :not_found} -> not_found(conn)
    end
  end
end
