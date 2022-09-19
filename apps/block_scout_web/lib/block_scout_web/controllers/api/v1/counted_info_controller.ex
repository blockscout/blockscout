defmodule BlockScoutWeb.API.V1.CountedInfoController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.APILogger
  alias Explorer.Chain
  alias Explorer.Chain.Cache.Block, as: BlockCache
  alias Explorer.Chain.Cache.Transaction, as: TransactionCache

  def counted_info(conn, _) do
    APILogger.log(conn)
    try do
      total_transactions = TransactionCache.estimated_count()
      total_blocks = BlockCache.estimated_count()
      wallet_addresses = Chain.address_estimated_count()

      send_resp(conn, :ok, result(total_transactions,
                                  total_blocks,
                                  wallet_addresses
        )
      )
    rescue
      e in RuntimeError -> send_resp(conn, :internal_server_error, error(e))
    end
  end

  defp result(total_transactions, total_blocks, wallet_addresses) do
    %{
      "total_transactions" => total_transactions,
      "total_blocks" => total_blocks,
      "wallet_addresses" => wallet_addresses
    }
    |> Jason.encode!()
  end

  defp error(e) do
    %{
      "error" => e
    }
    |> Jason.encode!()
  end
end