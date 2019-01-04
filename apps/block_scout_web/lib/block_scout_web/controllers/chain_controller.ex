defmodule BlockScoutWeb.ChainController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.ChainView
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market
  alias Phoenix.View

  def show(conn, _params) do
    transaction_estimated_count = Chain.transaction_estimated_count()

    exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()

    render(
      conn,
      "show.html",
      address_count: Chain.count_addresses_with_balance_from_cache(),
      average_block_time: AverageBlockTime.average_block_time(),
      exchange_rate: exchange_rate,
      chart_data_path: market_history_chart_path(conn, :show),
      transaction_estimated_count: transaction_estimated_count,
      transactions_path: recent_transactions_path(conn, :index)
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

  def chain_blocks(conn, _params) do
    if ajax?(conn) do
      blocks =
        [paging_options: %PagingOptions{page_size: 4}]
        |> Chain.list_blocks()
        |> Repo.preload([[miner: :names], :transactions, :rewards])
        |> Enum.map(fn block ->
          %{
            chain_block_html:
              View.render_to_string(
                ChainView,
                "_block.html",
                block: block
              ),
            block_number: block.number
          }
        end)

      json(conn, %{blocks: blocks})
    else
      unprocessable_entity(conn)
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
