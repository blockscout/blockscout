defmodule BlockScoutWeb.ChainController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1]

  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.{ChainView, Controller}
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.Chain.Cache.Block, as: BlockCache
  # alias Explorer.Chain.Cache.GasUsage
  alias Explorer.Chain.Cache.Transaction, as: TransactionCache
  alias Explorer.Chain.Supply.RSK
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market
  alias Phoenix.View

  def show(conn, _params) do
    transaction_estimated_count = TransactionCache.estimated_count()
    # total_gas_usage = GasUsage.total()
    block_count = BlockCache.estimated_count()
    address_count = Chain.address_estimated_count()

    market_cap_calculation =
      case Application.get_env(:explorer, :supply) do
        RSK ->
          RSK

        _ ->
          :standard
      end

    exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()

    transaction_stats = Helper.get_transaction_stats()

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
      |> Chain.joint_search(offset, term)

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
