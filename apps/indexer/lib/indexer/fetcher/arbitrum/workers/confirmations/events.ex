# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Events do
  @moduledoc """
  Provides functionality for fetching and parsing Arbitrum's SendRootUpdated events.

  This module is responsible for retrieving event logs from the Arbitrum Outbox
  contract and extracting rollup block hashes from SendRootUpdated events.
  """

  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
  alias Indexer.Helper, as: IndexerHelper

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_debug: 1]

  require Logger

  @doc """
    Retrieves `SendRootUpdated` event logs from the `Outbox` contract for a specified block range.

    ## Parameters
    - `start_block`: Starting block number for log retrieval
    - `end_block`: Ending block number for log retrieval
    - `outbox_address`: Address of the `Outbox` contract
    - `json_rpc_named_arguments`: JSON RPC connection configuration

    ## Returns
    - List of `SendRootUpdated` event logs

    ## Raises
    - `MatchError` if the RPC node does not give the logs after the retries. The
      caller reads the same block range again in its next run.
  """
  @spec get_logs_for_confirmations(
          non_neg_integer(),
          non_neg_integer(),
          binary(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: [%{String.t() => any()}]
  def get_logs_for_confirmations(start_block, end_block, outbox_address, json_rpc_named_arguments)
      when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        outbox_address,
        [ArbitrumEvents.send_root_updated()],
        json_rpc_named_arguments
      )

    unless Enum.empty?(logs) do
      log_debug("Found #{length(logs)} SendRootUpdated logs")
    end

    logs
  end

  @doc """
    Extracts the rollup block hash from a `SendRootUpdated` event log.

    ## Parameters
    - `event`: Event log map from `eth_getLogs` containing "topics" array where
      the rollup block hash is the third element

    ## Returns
    - A rollup block hash in hex format starting with "0x"
  """
  @spec send_root_updated_event_parse(%{String.t() => any()}) :: String.t()
  def send_root_updated_event_parse(event) do
    [_, _, l2_block_hash] = event["topics"]

    l2_block_hash
  end
end
