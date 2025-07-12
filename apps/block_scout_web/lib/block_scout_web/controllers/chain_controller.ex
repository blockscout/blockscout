defmodule BlockScoutWeb.ChainController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1]

  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.{ChainView, Controller}
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Block, Hash, Transaction}
  alias Explorer.Chain.Cache.Counters.{AddressesCount, AverageBlockTime, BlocksCount, GasUsageSum, TransactionsCount}
  alias Explorer.Chain.Search
  alias Explorer.Chain.Supply.RSK
  alias Explorer.Market
  alias Phoenix.View

  def show(conn, _params) do
    transaction_count = TransactionsCount.get()
    total_gas_usage = GasUsageSum.total()
    block_count = BlocksCount.get()
    address_count = AddressesCount.fetch()

    market_cap_calculation =
      case Application.get_env(:explorer, :supply) do
        RSK ->
          RSK

        _ ->
          :standard
      end

    exchange_rate = Market.get_coin_exchange_rate()

    transaction_stats = Helper.get_transaction_stats()

    chart_data_paths = %{
      market: market_history_chart_path(conn, :show),
      transaction: transaction_history_chart_path(conn, :show)
    }

    chart_config = Application.get_env(:block_scout_web, :chart)[:chart_config]

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
      transaction_estimated_count: transaction_count,
      total_gas_usage: total_gas_usage,
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
    search_path =
      conn
      |> search_path(:search_results, q: query)
      |> Controller.full_path()

    query
    |> String.trim()
    |> BlockScoutWeb.Chain.from_param()
    |> case do
      {:ok, item} ->
        redirect_search_results(conn, item, search_path)

      {:error, :not_found} ->
        redirect(conn, to: search_path)
    end
  end

  def search(conn, _), do: not_found(conn)

  def token_autocomplete(conn, %{"q" => term} = params) when is_binary(term) do
    [paging_options: paging_options] = paging_options(params)

    {results, _} =
      paging_options
      |> Search.joint_search(term)

    encoded_results =
      results
      |> Enum.map(fn item ->
        transaction_hash_bytes = Map.get(item, :transaction_hash)
        block_hash_bytes = Map.get(item, :block_hash)

        item =
          if transaction_hash_bytes do
            item
            |> Map.replace(:transaction_hash, full_hash_string(transaction_hash_bytes))
          else
            item
          end

        item =
          if block_hash_bytes do
            item
            |> Map.replace(:block_hash, full_hash_string(block_hash_bytes))
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

  defp redirect_search_results(conn, %Address{} = item, _search_path) do
    address_path =
      conn
      |> address_path(:show, item)
      |> Controller.full_path()

    redirect(conn, to: address_path)
  end

  defp redirect_search_results(conn, %Block{} = item, _search_path) do
    block_path =
      conn
      |> block_path(:show, item)
      |> Controller.full_path()

    redirect(conn, to: block_path)
  end

  defp redirect_search_results(conn, %Transaction{} = item, _search_path) do
    transaction_path =
      conn
      |> transaction_path(:show, item)
      |> Controller.full_path()

    redirect(conn, to: transaction_path)
  end

  defp redirect_search_results(conn, _item, search_path) do
    redirect(conn, to: search_path)
  end

  defp full_hash_string(%Hash{} = hash), do: to_string(hash)

  defp full_hash_string(bytes) when is_binary(bytes) do
    {:ok, hash} = Hash.Full.cast(bytes)
    to_string(hash)
  end
end
