defmodule ExplorerWeb.ChainController do
  use ExplorerWeb, :controller

  alias Explorer.{PagingOptions, Repo}
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market

  @address_count_module Application.get_env(:explorer_web, :fake_adapter) || Chain

  def show(conn, _params) do
    transaction_estimated_count = Chain.transaction_estimated_count()

    transactions =
      Chain.recent_collated_transactions(
        necessity_by_association: %{
          block: :required,
          from_address: :required,
          to_address: :optional
        },
        paging_options: %PagingOptions{page_size: 5}
      )

    blocks =
      [paging_options: %PagingOptions{page_size: 4}]
      |> Chain.list_blocks()
      |> Repo.preload([:miner, :transactions])

    render(
      conn,
      "show.html",
      address_estimated_count: @address_count_module.address_estimated_count(),
      average_block_time: Chain.average_block_time(),
      blocks: blocks,
      exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
      market_history_data: Market.fetch_recent_history(30),
      transaction_estimated_count: transaction_estimated_count,
      transactions: transactions
    )
  end

  def search(conn, %{"q" => query}) do
    query
    |> String.trim()
    |> ExplorerWeb.Chain.from_param()
    |> case do
      {:ok, item} ->
        redirect_search_results(conn, item)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp redirect_search_results(conn, %Address{} = item) do
    redirect(conn, to: address_path(conn, :show, Gettext.get_locale(), item))
  end

  defp redirect_search_results(conn, %Block{} = item) do
    redirect(conn, to: block_path(conn, :show, Gettext.get_locale(), item))
  end

  defp redirect_search_results(conn, %Transaction{} = item) do
    redirect(
      conn,
      to:
        transaction_path(
          conn,
          :show,
          Gettext.get_locale(),
          item
        )
    )
  end
end
