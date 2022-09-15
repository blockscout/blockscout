defmodule BlockScoutWeb.API.V1.CountedInfoController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.APILogger
  alias Explorer.Chain
  alias Explorer.Market
  alias Explorer.ExchangeRates.Token
  alias Explorer.Chain.Cache.Block, as: BlockCache
  alias Explorer.Chain.Cache.Transaction, as: TransactionCache
  alias Explorer.Counters.AverageBlockTime

  def counted_info(conn, _) do
    APILogger.log(conn)
    try do
      average_block_time = AverageBlockTime.average_block_time()
      total_transactions = TransactionCache.estimated_count()
      total_blocks = BlockCache.estimated_count()
      wallet_addresses = Chain.address_estimated_count()

      token = Market.get_exchange_rate(Explorer.coin()) || Token.null()

      price = token.usd_value
      volume_24h = token.volume_24h_usd
      circulating_supply = token.available_supply
      market_cap = token.market_cap_usd

      send_resp(conn, :ok, result(average_block_time,
                                  total_transactions,
                                  total_blocks,
                                  wallet_addresses,
                                  price,
                                  volume_24h,
                                  circulating_supply,
                                  market_cap
        )
      )
    rescue
      e in RuntimeError -> send_resp(conn, :internal_server_error, error(e))
    end
  end

  def result(average_block_time, total_transactions, total_blocks,
        wallet_addresses, price, volume_24h, circulating_supply, market_cap) do
    %{
      "average_block_time" => average_block_time |> Timex.Duration.to_seconds(),
      "total_transactions" => total_transactions,
      "total_blocks" => total_blocks,
      "wallet_addresses" => wallet_addresses,
      "price" => price,
      "volume_24h" => volume_24h,
      "circulating_supply" => circulating_supply,
      "market_cap" => market_cap
    }
    |> Jason.encode!()
  end

  def error(e) do
    %{
      "error" => e
    }
    |> Jason.encode!()
  end
end