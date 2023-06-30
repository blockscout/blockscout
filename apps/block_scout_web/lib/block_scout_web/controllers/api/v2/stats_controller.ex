defmodule BlockScoutWeb.API.V2.StatsController do
  use Phoenix.Controller

  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.Chain.MarketHistoryChartController
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Cache.Block, as: BlockCache
  alias Explorer.Chain.Cache.{GasPriceOracle, GasUsage}
  alias Explorer.Chain.Cache.Transaction, as: TransactionCache
  alias Explorer.Chain.Supply.RSK
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.Counters.AverageBlockTime
  alias Timex.Duration

  @api_true [api?: true]

  def stats(conn, _params) do
    market_cap_type =
      case Application.get_env(:explorer, :supply) do
        RSK ->
          RSK

        _ ->
          :standard
      end

    exchange_rate = Market.get_coin_exchange_rate()

    transaction_stats = Helper.get_transaction_stats()

    gas_prices =
      case GasPriceOracle.get_gas_prices() do
        {:ok, gas_prices} ->
          gas_prices

        _ ->
          nil
      end

    gas_price = Application.get_env(:block_scout_web, :gas_price)

    json(
      conn,
      %{
        "total_blocks" => BlockCache.estimated_count() |> to_string(),
        "total_addresses" => @api_true |> Chain.address_estimated_count() |> to_string(),
        "total_transactions" => TransactionCache.estimated_count() |> to_string(),
        "average_block_time" => AverageBlockTime.average_block_time() |> Duration.to_milliseconds(),
        "coin_price" => exchange_rate.usd_value,
        "total_gas_used" => GasUsage.total() |> to_string(),
        "transactions_today" => Enum.at(transaction_stats, 0).number_of_transactions |> to_string(),
        "gas_used_today" => Enum.at(transaction_stats, 0).gas_used,
        "gas_prices" => gas_prices,
        "static_gas_price" => gas_price,
        "market_cap" => Helper.market_cap(market_cap_type, exchange_rate),
        "network_utilization_percentage" => network_utilization_percentage()
      }
    )
  end

  defp network_utilization_percentage do
    {gas_used, gas_limit} =
      Enum.reduce(Chain.list_blocks(), {Decimal.new(0), Decimal.new(0)}, fn block, {gas_used, gas_limit} ->
        {Decimal.add(gas_used, block.gas_used), Decimal.add(gas_limit, block.gas_limit)}
      end)

    if Decimal.compare(gas_limit, 0) == :eq,
      do: 0,
      else: gas_used |> Decimal.div(gas_limit) |> Decimal.mult(100) |> Decimal.to_float()
  end

  def transactions_chart(conn, _params) do
    [{:history_size, history_size}] =
      Application.get_env(:block_scout_web, BlockScoutWeb.Chain.TransactionHistoryChartController, [{:history_size, 30}])

    today = Date.utc_today()
    latest = Date.add(today, -1)
    earliest = Date.add(latest, -1 * history_size)

    date_range = TransactionStats.by_date_range(earliest, latest, @api_true)

    transaction_history_data =
      date_range
      |> Enum.map(fn row ->
        %{date: row.date, tx_count: row.number_of_transactions}
      end)

    json(conn, %{
      chart_data: transaction_history_data
    })
  end

  def market_chart(conn, _params) do
    exchange_rate = Market.get_coin_exchange_rate()

    recent_market_history = Market.fetch_recent_history()
    current_total_supply = available_supply(Chain.supply_for_days(), exchange_rate)

    price_history_data =
      recent_market_history
      |> case do
        [today | the_rest] ->
          [
            %{
              today
              | closing_price: exchange_rate.usd_value
            }
            | the_rest
          ]

        data ->
          data
      end
      |> Enum.map(fn day -> Map.take(day, [:closing_price, :market_cap, :date]) end)

    market_history_data =
      MarketHistoryChartController.encode_market_history_data(price_history_data, current_total_supply)

    json(conn, %{
      chart_data: market_history_data,
      # todo: remove when new frontend is ready to use data from chart_data property only
      available_supply: current_total_supply
    })
  end

  defp available_supply(:ok, exchange_rate), do: exchange_rate.available_supply || 0

  defp available_supply({:ok, supply_for_days}, _exchange_rate), do: supply_for_days
end
