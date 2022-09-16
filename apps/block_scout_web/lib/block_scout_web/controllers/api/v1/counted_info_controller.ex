defmodule BlockScoutWeb.API.V1.CountedInfoController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.APILogger
  alias Explorer.Chain
  alias Explorer.Market
  alias Explorer.ExchangeRates.Token
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Chain.Cache.Block, as: BlockCache
  alias Explorer.Chain.Cache.Transaction, as: TransactionCache

  def counted_info(conn, _) do
    APILogger.log(conn)
    try do
      average_block_time = AverageBlockTime.average_block_time()
      total_transactions = TransactionCache.estimated_count()
      total_blocks = BlockCache.estimated_count()
      wallet_addresses = Chain.address_estimated_count()
      token_stats = Market.get_exchange_rate(Explorer.coin()) || Token.null()
      transaction_stats = get_transaction_stats() |> Enum.at(0)

      send_resp(conn, :ok, result(average_block_time,
                                  total_transactions,
                                  total_blocks,
                                  wallet_addresses,
                                  token_stats,
                                  transaction_stats
        )
      )
    rescue
      e in RuntimeError -> send_resp(conn, :internal_server_error, error(e))
    end
  end

  defp result(average_block_time, total_transactions, total_blocks,
         wallet_addresses, token_stats, transaction_stats) do
    tx_stats = %{
      "date" => transaction_stats.date,
      "number_of_transactions" => transaction_stats.number_of_transactions,
      "gas_used" => transaction_stats.gas_used,
      "total_fee" => transaction_stats.total_fee
    }
    %{
      "average_block_time" => average_block_time |> Timex.Duration.to_seconds(),
      "total_transactions" => total_transactions,
      "total_blocks" => total_blocks,
      "wallet_addresses" => wallet_addresses,
      "token_stats" => %{"price" => token_stats.usd_value,
                         "volume_24h" => token_stats.volume_24h_usd,
                         "circulating_supply" => token_stats.available_supply,
                         "market_cap" => token_stats.market_cap_usd},
      "transaction_stats" => tx_stats
    }
    |> Jason.encode!()
  end

  defp error(e) do
    %{
      "error" => e
    }
    |> Jason.encode!()
  end

  defp get_transaction_stats do
    stats_scale = date_range(1)
    transaction_stats = TransactionStats.by_date_range(stats_scale.earliest, stats_scale.latest)

    # Need datapoint for legend if none currently available.
    if Enum.empty?(transaction_stats) do
      [%{number_of_transactions: 0, gas_used: 0}]
    else
      transaction_stats
    end
  end

  defp date_range(num_days) do
    today = Date.utc_today()
    latest = Date.add(today, -1)
    x_days_back = Date.add(latest, -1 * (num_days - 1))
    %{earliest: x_days_back, latest: latest}
  end
end