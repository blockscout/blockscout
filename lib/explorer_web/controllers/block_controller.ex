defmodule ExplorerWeb.BlockController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Block
  alias Explorer.BlockForm
  alias Explorer.Repo.NewRelic, as: Repo

  def index(conn, params) do
    blocks = from block in Block,
      left_join: block_transaction in assoc(block, :block_transactions),
      left_join: transactions in assoc(block_transaction, :transaction),
      preload: [:transactions],
      order_by: [desc: block.number],
      group_by: block.id

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
