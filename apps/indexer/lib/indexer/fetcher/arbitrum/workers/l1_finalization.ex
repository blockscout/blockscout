defmodule Indexer.Fetcher.Arbitrum.Workers.L1Finalization do
  @moduledoc """
  TBD
  """

  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}

  alias Explorer.Chain

  require Logger

  def monitor_lifecycle_txs(json_rpc_named_arguments) do
    {:ok, safe_block} =
      IndexerHelper.get_block_number_by_tag(
        "safe",
        json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    lifecycle_txs = Db.lifecycle_unfinalized_transactions(safe_block)

    if length(lifecycle_txs) > 0 do
      Logger.info("Discovered #{length(lifecycle_txs)} lifecycle transaction to be finalized")

      updated_lifecycle_txs =
        lifecycle_txs
        |> Enum.map(fn tx ->
          Map.put(tx, :status, :finalized)
        end)

      {:ok, _} =
        Chain.import(%{
          arbitrum_lifecycle_transactions: %{params: updated_lifecycle_txs},
          timeout: :infinity
        })
    end
  end
end
