defmodule ExplorerWeb.BlockController do
  use ExplorerWeb, :controller
  import Ecto.Query
  alias Explorer.Block
  alias Explorer.Repo
  alias Explorer.BlockForm

  def index(conn, params) do
    blocks = Block
      |> order_by(desc: :number)
      |> preload(:transactions)
      |> Repo.paginate(params)
    render(conn, "index.html", blocks: blocks)
  end

  def show(conn, params) do
    block = Block
      |> where(number: ^params["id"])
      |> first |> Repo.one
      |> BlockForm.build
    render(conn, "show.html", block: block)
  end
end
