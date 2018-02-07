defmodule ExplorerWeb.ChainController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Block
  alias Explorer.BlockForm
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction

  def show(conn, _params) do
    blocks = from b in Block,
      order_by: [desc: b.number],
      preload: :transactions,
      limit: 5

    transactions = from transaction in Transaction,
      inner_join: block_transaction in assoc(transaction, :block_transaction),
      left_join: block in assoc(block_transaction, :block),
      preload: [block_transaction: block_transaction, block: block],
      limit: 5,
      order_by: [desc: block.number],
      where: not is_nil(block.id)

    render(
      conn,
      "show.html",
      blocks: blocks |> Repo.all() |> Enum.map(&BlockForm.build/1),
      transactions: transactions |> Repo.all()
    )
  end
end
