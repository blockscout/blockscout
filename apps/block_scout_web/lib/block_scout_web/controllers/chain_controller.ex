defmodule BlockScoutWeb.ChainController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market

  def show(conn, _params) do
    blocks =
      [paging_options: %PagingOptions{page_size: 4}]
      |> Chain.list_blocks()
      |> Repo.preload([[miner: :names], :transactions])

    transaction_estimated_count = Chain.transaction_estimated_count()

    transactions =
      Chain.recent_collated_transactions(
        necessity_by_association: %{
          :block => :required,
          [created_contract_address: :names] => :optional,
          [from_address: :names] => :required,
          [to_address: :names] => :optional
        },
        paging_options: %PagingOptions{page_size: 5}
      )

    exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()

    market_history_data =
      case Market.fetch_recent_history(30) do
        [today | the_rest] -> [%{today | closing_price: exchange_rate.usd_value} | the_rest]
        data -> data
      end

    render(
      conn,
      "show.html",
      address_estimated_count: Chain.address_estimated_count(),
      average_block_time: Chain.average_block_time(),
      blocks: blocks,
      exchange_rate: exchange_rate,
      market_history_data: market_history_data,
      transaction_estimated_count: transaction_estimated_count,
      transactions: transactions
    )
  end

  def search(conn, %{"q" => query}) do
    query
    |> String.trim()
    |> BlockScoutWeb.Chain.from_param()
    |> case do
      {:ok, item} ->
        redirect_search_results(conn, item)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp redirect_search_results(conn, %Address{} = item) do
    redirect(conn, to: address_path(conn, :show, item))
  end

  defp redirect_search_results(conn, %Block{} = item) do
    redirect(conn, to: block_path(conn, :show, item))
  end

  defp redirect_search_results(conn, %Transaction{} = item) do
    redirect(
      conn,
      to:
        transaction_path(
          conn,
          :show,
          item
        )
    )
  end
end
