defmodule ExplorerWeb.BlockController do
  use ExplorerWeb, :controller
  import Ecto.Query
  alias Explorer.Block
  alias Explorer.Repo
  alias Explorer.BlockForm

  def show(conn, params) do
    block = Block
      |> where(id: ^params["id"])
      |> first |> Repo.one
      |> BlockForm.build
    render(conn, "show.html", block: block)
  end
end
