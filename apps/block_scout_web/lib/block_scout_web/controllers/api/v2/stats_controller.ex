defmodule BlockScoutWeb.API.V2.StatsController do
  use Phoenix.Controller
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.Chain.MarketHistoryChartController
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Cache.GasPriceOracle
  alias Explorer.Chain.Cache.Counters.{AddressesCount, AverageBlockTime, BlocksCount, GasUsageSum, TransactionsCount}
  alias Explorer.Chain.Supply.RSK
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Plug.Conn
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
    secondary_coin_exchange_rate = Market.get_secondary_coin_exchange_rate()

    transaction_stats = Helper.get_transaction_stats()

    gas_prices =
      case GasPriceOracle.get_gas_prices() do
        {:ok, gas_prices} ->
          gas_prices

        _ ->
          nil
      end

    coin_price_change =
      case Market.fetch_recent_history() do
        [_today, yesterday | _] ->
          exchange_rate.fiat_value && yesterday.closing_price &&
            exchange_rate.fiat_value
            |> Decimal.div(yesterday.closing_price)
            |> Decimal.sub(1)
            |> Decimal.mult(100)
            |> Decimal.to_float()
            |> Float.ceil(2)

        _ ->
          nil
      end

    gas_price = Application.get_env(:block_scout_web, :gas_price)

    json(
      conn,
      %{
        "total_blocks" => BlocksCount.get() |> to_string(),
        "total_addresses" => AddressesCount.fetch() |> to_string(),
        "total_transactions" => TransactionsCount.get() |> to_string(),
        "average_block_time" => AverageBlockTime.average_block_time() |> Duration.to_milliseconds(),
        "coin_image" => exchange_rate.image_url,
        "secondary_coin_image" => secondary_coin_exchange_rate.image_url,
        "coin_price" => exchange_rate.fiat_value,
        "coin_price_change_percentage" => coin_price_change,
        "secondary_coin_price" => secondary_coin_exchange_rate.fiat_value,
        "total_gas_used" => GasUsageSum.total() |> to_string(),
        "transactions_today" => Enum.at(transaction_stats, 0).number_of_transactions |> to_string(),
        "gas_used_today" => Enum.at(transaction_stats, 0).gas_used,
        "gas_prices" => gas_prices,
        "gas_prices_update_in" => GasPriceOracle.update_in(),
        "gas_price_updated_at" => GasPriceOracle.get_updated_at(),
        "static_gas_price" => gas_price,
        "market_cap" => Helper.market_cap(market_cap_type, exchange_rate),
        "tvl" => exchange_rate.tvl,
        "network_utilization_percentage" => network_utilization_percentage()
      }
      |> add_chain_type_fields()
      |> backward_compatibility(conn)
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
        # todo: `transaction_count` property should be removed in favour `transactions_count` property with the next release after 8.0.0
        %{date: row.date, transaction_count: row.number_of_transactions, transactions_count: row.number_of_transactions}
      end)

    json(conn, %{
      chart_data: transaction_history_data
    })
  end

  def market_chart(conn, _params) do
    exchange_rate = Market.get_coin_exchange_rate()

    recent_market_history = Market.fetch_recent_history()
    current_total_supply = MarketHistoryChartController.available_supply(Chain.supply_for_days(), exchange_rate)

    price_history_data =
      recent_market_history
      |> case do
        [today | the_rest] ->
          [
            %{
              today
              | closing_price: exchange_rate.fiat_value
            }
            | the_rest
          ]

        data ->
          data
      end
      |> Enum.map(fn day -> Map.take(day, [:closing_price, :market_cap, :tvl, :date]) end)

    market_history_data =
      MarketHistoryChartController.encode_market_history_data(price_history_data, current_total_supply)

    json(conn, %{
      chart_data: market_history_data,
      # todo: remove when new frontend is ready to use data from chart_data property only
      available_supply: current_total_supply
    })
  end

  def secondary_coin_market_chart(conn, _params) do
    recent_market_history = Market.fetch_recent_history(true)

    chart_data =
      recent_market_history
      |> Enum.map(fn day -> Map.take(day, [:closing_price, :date]) end)

    json(conn, %{
      chart_data: chart_data
    })
  end

  defp backward_compatibility(response, conn) do
    case Conn.get_req_header(conn, "updated-gas-oracle") do
      ["true"] ->
        response

      _ ->
        response
        |> Map.update("gas_prices", nil, fn
          gas_prices ->
            %{slow: gas_prices[:slow][:price], average: gas_prices[:average][:price], fast: gas_prices[:fast][:price]}
        end)
    end
  end

  case @chain_type do
    :rsk ->
      defp add_chain_type_fields(response) do
        alias Explorer.Chain.Cache.Counters.Rootstock.LockedBTCCount

        case LockedBTCCount.get_locked_value() do
          rootstock_locked_btc when not is_nil(rootstock_locked_btc) ->
            response |> Map.put("rootstock_locked_btc", rootstock_locked_btc)

          _ ->
            response
        end
      end

    :optimism ->
      defp add_chain_type_fields(response) do
        import Explorer.Chain.Cache.Counters.Optimism.LastOutputRootSizeCount, only: [fetch: 1]
        response |> Map.put("last_output_root_size", fetch(@api_true))
      end

    :celo ->
      defp add_chain_type_fields(response) do
        alias Explorer.Chain.Cache.CeloEpochs
        response |> Map.put("celo", %{"epoch_number" => CeloEpochs.last_block_epoch_number()})
      end

    _ ->
      defp add_chain_type_fields(response), do: response
  end
end
