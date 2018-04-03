defmodule ExplorerWeb.AddressController do
  use ExplorerWeb, :controller

  alias Explorer.Address.Service, as: Address

  def show(conn, %{"id" => id}) do
    address = id |> Address.by_hash()
    render(conn, "show.html", address: address)
  end
end
