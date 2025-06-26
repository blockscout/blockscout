defmodule Indexer.Fetcher.Arbitrum.Workers.Batches.Events do
  @moduledoc """
  Provides functionality for retrieving Arbitrum `SequencerBatchDelivered` event logs.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_debug: 1]

  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
  alias Indexer.Helper, as: IndexerHelper

  require Logger

  @doc """
    Fetches `SequencerBatchDelivered` event logs from the `SequencerInbox` contract within a block range.

    Filters transaction logs by the event signature and contract address, retrieving only
    events emitted by the `SequencerInbox` contract between the specified block numbers.

    ## Parameters
    - `start_block`: Starting block number of the search range (inclusive)
    - `end_block`: Ending block number of the search range (inclusive)
    - `sequencer_inbox_address`: Address of the `SequencerInbox` contract
    - `json_rpc_named_arguments`: Configuration for JSON-RPC connection

    ## Returns
    - List of event log entries matching the `SequencerBatchDelivered` signature
  """
  @spec get_logs_for_batches(non_neg_integer(), non_neg_integer(), binary(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          [%{String.t() => any()}]
  def get_logs_for_batches(start_block, end_block, sequencer_inbox_address, json_rpc_named_arguments)
      when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        sequencer_inbox_address,
        [ArbitrumEvents.sequencer_batch_delivered()],
        json_rpc_named_arguments
      )

    if length(logs) > 0 do
      log_debug("Found #{length(logs)} SequencerBatchDelivered logs")
    end

    logs
  end
end
