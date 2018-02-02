defmodule ExplorerWeb.AddressController do
  use ExplorerWeb, :controller
  import Ecto.Query
  alias Explorer.Address
  alias Explorer.Repo
  alias Explorer.AddressForm

  def show(conn, params) do
    address = Address
      |> where(hash: ^params["id"])
      |> first
      |> Repo.one
      |> AddressForm.build
    render(conn, "show.html", address: address)
  end
end
