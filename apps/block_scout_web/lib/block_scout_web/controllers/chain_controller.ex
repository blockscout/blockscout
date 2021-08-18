defmodule BlockScoutWeb.ChainController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1]

  alias BlockScoutWeb.{ChainView, Controller}
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.Chain.Supply.{RSK, TokenBridge}
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market
  alias Phoenix.View

  def show(conn, _params) do
    transaction_estimated_count = Chain.transaction_estimated_count()
    # total_gas_usage = Chain.total_gas_usage()
    block_count = Chain.block_estimated_count()
    address_count = Chain.address_estimated_count()

    market_cap_calculation =
      case Application.get_env(:explorer, :supply) do
        RSK ->
          RSK

        TokenBridge ->
          TokenBridge

        _ ->
          :standard
      end

    exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()

    transaction_stats = get_transaction_stats()

    chart_data_paths = %{
      market: market_history_chart_path(conn, :show),
      transaction: transaction_history_chart_path(conn, :show)
    }

    chart_config = Application.get_env(:block_scout_web, :chart_config, %{})

    render(
      conn,
      "show.html",
      address_count: address_count,
      average_block_time: AverageBlockTime.average_block_time(),
      exchange_rate: exchange_rate,
      chart_config: chart_config,
      chart_config_json: Jason.encode!(chart_config),
      chart_data_paths: chart_data_paths,
      market_cap_calculation: market_cap_calculation,
      transaction_estimated_count: transaction_estimated_count,
      # total_gas_usage: total_gas_usage,
      transactions_path: recent_transactions_path(conn, :index),
      transaction_stats: transaction_stats,
      block_count: block_count,
      gas_price: Application.get_env(:block_scout_web, :gas_price)
    )
  end

  def get_transaction_stats do
    stats_scale = date_range(1)
    transaction_stats = TransactionStats.by_date_range(stats_scale.earliest, stats_scale.latest)

    # Need datapoint for legend if none currently available.
    if Enum.empty?(transaction_stats) do
      [%{number_of_transactions: 0, gas_used: 0}]
    else
      transaction_stats
    end
  end

  def date_range(num_days) do
    today = Date.utc_today()
    latest = Date.add(today, -1)
    x_days_back = Date.add(latest, -1 * (num_days - 1))
    %{earliest: x_days_back, latest: latest}
  end

  def search(conn, %{"q" => ""}) do
    show(conn, [])
  end

  def search(conn, %{"q" => query}) do
    query
    |> String.trim()
    |> BlockScoutWeb.Chain.from_param()
    |> case do
      {:ok, item} ->
        redirect_search_results(conn, item)

      {:error, :not_found} ->
        search_path =
          conn
          |> search_path(:search_results, q: query)
          |> Controller.full_path()

        redirect(conn, to: search_path)
    end
  end

  def search(conn, _), do: not_found(conn)

  def token_autocomplete(conn, %{"q" => term} = params) when is_binary(term) do
    [paging_options: paging_options] = paging_options(params)
    offset = (max(paging_options.page_number, 1) - 1) * paging_options.page_size

    results =
      paging_options
      |> search_by(offset, term)

    encoded_results =
      results
      |> Enum.map(fn item ->
        tx_hash_bytes = Map.get(item, :tx_hash)
        block_hash_bytes = Map.get(item, :block_hash)

        item =
          if tx_hash_bytes do
            item
            |> Map.replace(:tx_hash, "0x" <> Base.encode16(tx_hash_bytes, case: :lower))
          else
            item
          end

        item =
          if block_hash_bytes do
            item
            |> Map.replace(:block_hash, "0x" <> Base.encode16(block_hash_bytes, case: :lower))
          else
            item
          end

        item
      end)

    json(conn, encoded_results)
  end

  def token_autocomplete(conn, _) do
    json(conn, "{}")
  end

  def search_by(paging_options, offset, term) do
    Chain.joint_search(paging_options, offset, term)
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
    address_path =
      conn
      |> address_path(:show, item)
      |> Controller.full_path()

    redirect(conn, to: address_path)
  end

  defp redirect_search_results(conn, %Block{} = item) do
    block_path =
      conn
      |> block_path(:show, item)
      |> Controller.full_path()

    redirect(conn, to: block_path)
  end

  defp redirect_search_results(conn, %Transaction{} = item) do
    transaction_path =
      conn
      |> transaction_path(:show, item)
      |> Controller.full_path()

    redirect(conn, to: transaction_path)
  end
end
