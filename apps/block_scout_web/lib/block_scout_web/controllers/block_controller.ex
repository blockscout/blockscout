defmodule BlockScoutWeb.BlockController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias Explorer.Chain

  def index(conn, params) do
    [
      necessity_by_association: %{
        :transactions => :optional,
        [miner: :names] => :optional
      }
    ]
    |> Keyword.merge(paging_options(params))
    |> handle_render(conn, params)
  end

  def show(conn, %{"hash_or_number" => hash_or_number}) do
    redirect(conn, to: block_transaction_path(conn, :index, hash_or_number))
  end

  def reorg(conn, params) do
    [
      necessity_by_association: %{
        :transactions => :optional,
        [miner: :names] => :optional
      },
      block_type: "Reorg"
    ]
    |> Keyword.merge(paging_options(params))
    |> handle_render(conn, params)
  end

  def uncle(conn, params) do
    [
      necessity_by_association: %{
        :transactions => :optional,
        [miner: :names] => :optional,
        :nephews => :required
      },
      block_type: "Uncle"
    ]
    |> Keyword.merge(paging_options(params))
    |> handle_render(conn, params)
  end

  defp handle_render(full_options, conn, params) do
    blocks_plus_one = Chain.list_blocks(full_options)

    {blocks, next_page} = split_list_by_page(blocks_plus_one)

    render(conn, "index.html",
      blocks: blocks,
      next_page_params: next_page_params(next_page, blocks, params),
      block_type: Keyword.get(full_options, :block_type, "Block")
    )
  end
end
