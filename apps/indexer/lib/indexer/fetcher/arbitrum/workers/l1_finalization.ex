defmodule Indexer.Fetcher.Arbitrum.Workers.L1Finalization do
  @moduledoc """
    Oversees the finalization of lifecycle transactions on Layer 1 (L1) for Arbitrum rollups.

    This module is tasked with monitoring and updating the status of Arbitrum
    lifecycle transactions that are related to the rollup process. It ensures that
    transactions which have been confirmed up to the 'safe' block number on L1 are
    marked as 'finalized' within the system's database.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  alias Indexer.Fetcher.Arbitrum.Utils.Db.ParentChainTransactions, as: Db
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain

  require Logger

  @doc """
    Determines whether settlement transactions finalization should be run based on configuration.

    ## Parameters
    - A map containing configuration with L1 RPC settings.

    ## Returns
    - `true` if finalization tracking is enabled in the configuration
    - `false` otherwise
  """
  @spec run_settlement_transactions_finalization?(%{
          :config => %{
            :l1_rpc => %{
              :track_finalization => boolean(),
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: boolean()
  def run_settlement_transactions_finalization?(%{config: %{l1_rpc: %{track_finalization: track_finalization}}}) do
    track_finalization
  end

  @doc """
    Monitors and updates the status of lifecycle transactions related an Arbitrum rollup to 'finalized'.

    This function retrieves the current 'safe' block number from L1 and identifies
    lifecycle transactions that are not yet finalized up to this block. It then
    updates the status of these transactions to 'finalized' and imports the updated
    data into the database.

    ## Parameters
    - A map containing:
      - `config`: Configuration settings including JSON RPC arguments for L1 used
        to fetch the 'safe' block number.

    ## Returns
    - `:ok`
  """
  @spec monitor_lifecycle_transactions(%{
          :config => %{
            :l1_rpc => %{
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: :ok
  def monitor_lifecycle_transactions(
        %{config: %{l1_rpc: %{json_rpc_named_arguments: json_rpc_named_arguments}}} = _state
      ) do
    {:ok, safe_block} =
      IndexerHelper.get_block_number_by_tag(
        "safe",
        json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    lifecycle_transactions = Db.lifecycle_unfinalized_transactions(safe_block)

    if length(lifecycle_transactions) > 0 do
      log_info("Discovered #{length(lifecycle_transactions)} lifecycle transaction to be finalized")

      updated_lifecycle_transactions =
        lifecycle_transactions
        |> Enum.map(fn transaction ->
          Map.put(transaction, :status, :finalized)
        end)

      {:ok, _} =
        Chain.import(%{
          arbitrum_lifecycle_transactions: %{params: updated_lifecycle_transactions},
          timeout: :infinity
        })
    end

    :ok
  end
end
