defmodule ExplorerWeb.ChainController do
  use ExplorerWeb, :controller

  import Ecto.Query

  alias Explorer.Block
  alias Explorer.BlockForm
  alias Explorer.Chain
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction

  def show(conn, _params) do
    blocks = from block in Block,
      order_by: [desc: block.number],
      preload: :transactions,
      limit: 5

    transactions = from transaction in Transaction,
      join: block in assoc(transaction, :block),
      order_by: [desc: block.number],
      preload: [block: block],
      limit: 5

    render(
      conn,
      "show.html",
      blocks: blocks |> Repo.all() |> Enum.map(&BlockForm.build/1),
      transactions: transactions |> Repo.all(),
      chain: Chain.fetch()
    )
  end
end
