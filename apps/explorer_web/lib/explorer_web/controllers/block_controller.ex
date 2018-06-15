defmodule ExplorerWeb.BlockController do
  use ExplorerWeb, :controller

  import ExplorerWeb.Chain, only: [paging_options: 1]

  alias Explorer.Chain

  @page_size 50

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

    {blocks, next_page} = Enum.split(blocks_plus_one, @page_size)

    render(conn, "index.html", blocks: blocks, next_page_params: next_page_params(next_page, blocks))
  end

  def show(conn, %{"id" => number, "locale" => locale}) do
    redirect(conn, to: block_transaction_path(conn, :index, locale, number))
  end

  defp next_page_params([], _blocks), do: nil

  defp next_page_params(_, blocks) do
    last = List.last(blocks)
    %{block_number: last.number}
  end
end
