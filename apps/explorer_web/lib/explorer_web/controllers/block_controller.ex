defmodule ExplorerWeb.BlockController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Block
  alias Explorer.Repo.NewRelic, as: Repo
  alias ExplorerWeb.BlockForm

  def index(conn, params) do
    blocks =
      from(
        block in Block,
        order_by: [desc: block.number],
        preload: :transactions
      )

    render(conn, "index.html", blocks: Repo.paginate(blocks, params))
  end

  def show(conn, %{"id" => number}) do
    block =
      Block
      |> where(number: ^number)
      |> first
      |> Repo.one()
      |> BlockForm.build()

    render(conn, "show.html", block: block)
  end
end
