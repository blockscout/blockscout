defmodule ExplorerWeb.AddressController do
  use ExplorerWeb, :controller
  import Ecto.Query
  alias Explorer.Address
  alias Explorer.Repo

  def show(conn, params) do
    address = Address
      |> where(hash: ^params["id"])
      |> first
      |> Repo.one
    render(conn, "show.html", address: address)
  end
end
