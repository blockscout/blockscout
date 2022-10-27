defmodule BlockScoutWeb.API.V2.MainPageController do
  use Phoenix.Controller

  alias Explorer.{Chain, PagingOptions}
  alias BlockScoutWeb.API.V2.{BlockView, TransactionView}
  alias Explorer.{Chain, Repo}

  def blocks(conn, _params) do
    blocks =
      [paging_options: %PagingOptions{page_size: 4}]
      |> Chain.list_blocks()
      |> Repo.preload([[miner: :names], :transactions, :rewards])

    conn
    |> put_status(200)
    |> put_view(BlockView)
    |> render(:blocks, %{blocks: blocks})
  end

  def transactions(conn, _params) do
    recent_transactions =
      Chain.recent_collated_transactions(
        necessity_by_association: %{
          :block => :required,
          [created_contract_address: :names] => :optional,
          [from_address: :names] => :optional,
          [to_address: :names] => :optional,
          [created_contract_address: :smart_contract] => :optional,
          [from_address: :smart_contract] => :optional,
          [to_address: :smart_contract] => :optional
        },
        paging_options: %PagingOptions{page_size: 5}
      )

    conn
    |> put_status(200)
    |> put_view(TransactionView)
    |> render(:transactions, %{transactions: recent_transactions})
  end
end
