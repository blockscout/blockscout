defmodule ExplorerWeb.BlockController do
  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, params) do
    blocks = Chain.list_blocks(necessity_by_association: %{transactions: :optional}, pagination: params)

    render(conn, "index.html", blocks: blocks)
  end

  def show(conn, %{"id" => number}) do
    case Chain.number_to_block(number) do
      {:ok, block} ->
        block_transaction_count = Chain.block_to_transaction_count(block)
        render(conn, "show.html", block: block, block_transaction_count: block_transaction_count)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
