defmodule BlockScoutWeb.ChainController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.ChainView
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market
  alias Phoenix.View

  def show(conn, _params) do
    transaction_estimated_count = Chain.transaction_estimated_count()

    exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()

    market_history_data =
      case Market.fetch_recent_history(30) do
        [today | the_rest] -> [%{today | closing_price: exchange_rate.usd_value} | the_rest]
        data -> data
      end

    render(
      conn,
      "show.html",
      address_count: Chain.count_addresses_with_balance_from_cache(),
      average_block_time: Chain.average_block_time(),
      exchange_rate: exchange_rate,
      available_supply: available_supply(Chain.supply_for_days(30), exchange_rate),
      market_history_data: market_history_data,
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

  defp available_supply(:ok, exchange_rate) do
    to_string(exchange_rate.available_supply || 0)
  end

  defp available_supply({:ok, supply_for_days}, _exchange_rate) do
    supply_for_days
    |> Jason.encode()
    |> case do
      {:ok, data} -> data
      _ -> []
    end
  end
end
