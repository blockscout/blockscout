defmodule ExplorerWeb.BlockController do
  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, params) do
    blocks = Chain.list_blocks(necessity_by_association: %{transactions: :optional}, pagination: params)

    render(conn, "index.html", blocks: blocks)
  end

  def show(conn, %{"id" => number, "locale" => locale}) do
    redirect(conn, to: block_transaction_path(conn, :index, locale, number))
  end
end
