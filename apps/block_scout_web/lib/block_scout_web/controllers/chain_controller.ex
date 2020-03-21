defmodule BlockScoutWeb.ChainController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.ChainView
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.Chain.Supply.RSK
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market
  alias Phoenix.View

  def show(conn, _params) do
    transaction_estimated_count = Chain.transaction_estimated_count()
    block_count = Chain.block_estimated_count()
    address_count = Chain.address_estimated_count()

    market_cap_calculation =
      case Application.get_env(:explorer, :supply) do
        RSK ->
          RSK

        _ ->
          :standard
      end

    exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()

    render(
      conn,
      "show.html",
      address_count: address_count,
      average_block_time: AverageBlockTime.average_block_time(),
      exchange_rate: exchange_rate,
      chart_data_path: market_history_chart_path(conn, :show),
      market_cap_calculation: market_cap_calculation,
      transaction_estimated_count: transaction_estimated_count,
      transactions_path: recent_transactions_path(conn, :index),
      block_count: block_count
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

  def search(conn, _), do: not_found(conn)

  def token_autocomplete(conn, %{"q" => term}) when is_binary(term) do
    if term == "" do
      json(conn, "{}")
    else
      result_tokens =
        term
        |> String.trim()
        |> Chain.search_token()

      if result_tokens do
        json(conn, result_tokens)
      else
        result_contracts =
          term
          |> String.trim()
          |> Chain.search_contract()

        json(conn, result_contracts)
      end
    end
  end

  def token_autocomplete(conn, _) do
    json(conn, "{}")
  end

  def chain_blocks(conn, _params) do
    if ajax?(conn) do
      blocks =
        [
          paging_options: %PagingOptions{page_size: 4},
          necessity_by_association: %{
            [miner: :names] => :optional,
            :transactions => :optional,
            :rewards => :optional
          }
        ]
        |> Chain.list_blocks()
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
