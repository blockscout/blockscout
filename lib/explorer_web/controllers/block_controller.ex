defmodule ExplorerWeb.BlockController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Block
  alias Explorer.BlockForm
  alias Explorer.Repo.NewRelic, as: Repo

  def index(conn, params) do
    blocks = from b in Block,
      order_by: [desc: b.number],
      preload: :transactions

    render(conn, "index.html", blocks: Repo.paginate(blocks, params))
  end

  def show(conn, params) do
    block = Block
      |> where(number: ^params["id"])
      |> first |> Repo.one
      |> BlockForm.build
    render(conn, "show.html", block: block)
  end
end
