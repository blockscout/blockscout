defmodule BlockScoutWeb.BlockController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias Explorer.Chain

  def index(conn, params) do
    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            transactions: :optional
          }
        ],
        paging_options(params)
      )

    blocks_plus_one = Chain.list_blocks(full_options)

    {blocks, next_page} = split_list_by_page(blocks_plus_one)

    render(conn, "index.html", blocks: blocks, next_page_params: next_page_params(next_page, blocks, params))
  end

  def show(conn, %{"id" => number}) do
    redirect(conn, to: block_transaction_path(conn, :index, number))
  end
end
