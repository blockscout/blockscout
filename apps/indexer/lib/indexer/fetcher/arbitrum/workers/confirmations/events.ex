defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Events do
  @moduledoc """
  Provides functionality for fetching and parsing Arbitrum's SendRootUpdated events.

  This module is responsible for retrieving event logs from the Arbitrum Outbox
  contract and extracting rollup block hashes from SendRootUpdated events. It
  implements caching mechanisms to optimize RPC calls when fetching logs for the
  same block ranges.
  """

  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
  alias Indexer.Helper, as: IndexerHelper

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_debug: 1]

  require Logger

  @typedoc """
    A map containing list of transaction logs for a specific block range.
    - the key is the tuple with the start and end of the block range
    - the value is the list of transaction logs received for the block range
  """
  @type cached_logs :: %{{non_neg_integer(), non_neg_integer()} => [%{String.t() => any()}]}

  @doc """
    Retrieves `SendRootUpdated` event logs from the `Outbox` contract for a specified block range.

    Fetches logs either from the provided cache to minimize RPC calls, or directly from
    the RPC node if not cached. Updates the cache with newly fetched logs.

    ## Parameters
    - `start_block`: Starting block number for log retrieval
    - `end_block`: Ending block number for log retrieval
    - `outbox_address`: Address of the `Outbox` contract
    - `json_rpc_named_arguments`: JSON RPC connection configuration
    - `cache`: Optional map of previously fetched logs, defaults to empty map

    ## Returns
    - Tuple containing:
      * List of `SendRootUpdated` event logs
      * Updated cache including newly fetched logs
  """
  @spec get_logs_for_confirmations(
          non_neg_integer(),
          non_neg_integer(),
          binary(),
          EthereumJSONRPC.json_rpc_named_arguments(),
          __MODULE__.cached_logs()
        ) :: {[%{String.t() => any()}], __MODULE__.cached_logs()}
  def get_logs_for_confirmations(start_block, end_block, outbox_address, json_rpc_named_arguments, cache \\ %{})
      when start_block <= end_block do
    # TODO: consider to have a persistent cache in DB to reduce the number of getLogs requests
    {logs, new_cache} =
      case cache[{start_block, end_block}] do
        nil ->
          {:ok, rpc_logs} =
            IndexerHelper.get_logs(
              start_block,
              end_block,
              outbox_address,
              [ArbitrumEvents.send_root_updated()],
              json_rpc_named_arguments
            )

          {rpc_logs, Map.put(cache, {start_block, end_block}, rpc_logs)}

        cached_logs ->
          {cached_logs, cache}
      end

    if length(logs) > 0 do
      log_debug("Found #{length(logs)} SendRootUpdated logs")
    end

    {logs, new_cache}
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
