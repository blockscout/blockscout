defmodule BlockScoutWeb.API.V2.StatsController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    chain_identity: [:explorer, :chain_identity]

  import BlockScoutWeb.PagingHelper, only: [hot_smart_contracts_sorting: 1, delete_items_count_from_next_page_params: 1]

  import BlockScoutWeb.Chain,
    only: [
      hot_smart_contracts_paging_options: 1,
      split_list_by_page: 1,
      next_page_params: 5,
      fetch_scam_token_toggle: 2
    ]

  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]

  alias OpenApiSpex.Schema

  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.Chain.MarketHistoryChartController
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Cache.Counters.{AddressesCount, AverageBlockTime, BlocksCount, GasUsageSum, TransactionsCount}
  alias Explorer.Chain.Cache.GasPriceOracle
  alias Explorer.Chain.Supply.RSK
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.Stats.HotSmartContracts
  alias Plug.Conn
  alias Timex.Duration

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["stats"])

  @api_true [api?: true]

  operation :stats,
    summary: "Retrieve blockchain network statistics and metrics",
    description:
      "Retrieves blockchain network statistics including total blocks, transactions, addresses, average block time, market data, and network utilization.",
    parameters: base_params(),
    responses: [
      ok: {"Blockchain network statistics.", "application/json", Schemas.Stats.Response},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Returns current indexing progress, chain stats and market data used on the UI.
  """
  @spec stats(Plug.Conn.t(), map()) :: Plug.Conn.t()
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
      |> add_chain_identity_fields()
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

  operation :transactions_chart,
    summary: "Get daily transaction counts",
    description: "Retrieves time series data of daily transaction counts for rendering charts.",
    parameters: base_params(),
    responses: [
      ok:
        {"Time series data for transaction count charts.", "application/json",
         %Schema{type: :object, properties: %{chart_data: %Schema{type: :array, items: %Schema{type: :object}}}}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Returns transaction counts by date chart.
  """
  @spec transactions_chart(Plug.Conn.t(), map()) :: Plug.Conn.t()
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
        %{date: row.date, transactions_count: row.number_of_transactions}
      end)

    json(conn, %{
      chart_data: transaction_history_data
    })
  end

  operation :market_chart,
    summary: "Get daily closing price and market cap for native coin",
    description:
      "Retrieves time series data of market information (daily closing price, market cap) for rendering charts.",
    parameters: base_params(),
    responses: [
      ok:
        {"Time series data for market charts and available token supply.", "application/json",
         %Schema{
           type: :object,
           properties: %{
             chart_data: %Schema{type: :array, items: %Schema{type: :object}},
             available_supply: %Schema{anyOf: [Schemas.General.FloatString, %Schema{type: :integer}]}
           }
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Returns market history (price, market cap, tvl) for charting.
  """
  @spec market_chart(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  operation :secondary_coin_market_chart,
    summary: "Secondary coin market history chart data",
    description: "Returns market history for the secondary coin used for charting.",
    parameters: base_params(),
    responses: [
      ok:
        {"Secondary coin market chart data.", "application/json",
         %Schema{type: :object, properties: %{chart_data: %Schema{type: :array, items: %Schema{type: :object}}}}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Returns market history for the secondary coin used for charting.
  """
  @spec secondary_coin_market_chart(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def secondary_coin_market_chart(conn, _params) do
    recent_market_history = Market.fetch_recent_history(true)

    chart_data =
      recent_market_history
      |> Enum.map(fn day -> Map.take(day, [:closing_price, :date]) end)

    json(conn, %{
      chart_data: chart_data
    })
  end

  operation :hot_smart_contracts,
    summary: "Retrieve hot smart-contracts",
    description: "Retrieves paginated list of hot smart-contracts",
    parameters:
      base_params() ++
        [sort_param(["transactions_count", "total_gas_used"]), order_param(), hot_smart_contracts_scale_param()] ++
        define_paging_params([
          "transactions_count_positive",
          "total_gas_used",
          "contract_address_hash_not_nullable",
          "items_count"
        ]),
    responses: [
      ok:
        {"Paginated list of hot smart-contracts.", "application/json",
         paginated_response(
           items: Schemas.Stats.HotContract,
           next_page_params_example: %{
             "transactions_count" => 100,
             "total_gas_used" => "100",
             "contract_address_hash" => "0x01a2A10583675E0e5dF52DE1b62734109201477a",
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response(),
      forbidden: ForbiddenResponse.response()
    ]

  @spec hot_smart_contracts(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def hot_smart_contracts(conn, %{scale: scale} = params) do
    options =
      params
      |> hot_smart_contracts_paging_options()
      |> Keyword.merge(hot_smart_contracts_sorting(params))
      |> Keyword.merge(@api_true)
      |> fetch_scam_token_toggle(conn)

    {hot_smart_contracts, next_page} =
      scale
      |> HotSmartContracts.paginated(options)
      |> case do
        {:error, :not_found} -> []
        hot_smart_contracts -> hot_smart_contracts
      end
      |> split_list_by_page()

    next_page_params =
      next_page
      |> next_page_params(hot_smart_contracts, params, false, &hot_smart_contracts_paging_params/1)
      |> delete_items_count_from_next_page_params()

    conn
    |> put_status(200)
    |> render(:hot_smart_contracts, %{
      hot_smart_contracts: hot_smart_contracts |> maybe_preload_metadata(),
      next_page_params: next_page_params
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

    _ ->
      defp add_chain_type_fields(response), do: response
  end

  case @chain_identity do
    {:optimism, :celo} ->
      defp add_chain_identity_fields(response) do
        alias Explorer.Chain.Cache.CeloEpochs
        response |> Map.put("celo", %{"epoch_number" => CeloEpochs.last_block_epoch_number()})
      end

    _ ->
      defp add_chain_identity_fields(response), do: response
  end

  defp hot_smart_contracts_paging_params(hot_contract) do
    %{
      contract_address_hash: hot_contract.contract_address_hash,
      transactions_count: hot_contract.transactions_count,
      total_gas_used: hot_contract.total_gas_used
    }
  end
end
