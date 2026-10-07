# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery do
  @moduledoc """
    Reads one window of the parent chain and prepares the confirmations of rollup
    blocks that the window holds.

    A window is a range of parent chain blocks. The module fetches the
    `SendRootUpdated` events of the Arbitrum `Outbox` contract in the window. Each
    event names the hash of a rollup block `top`. The event confirms this block and
    all rollup blocks below it.

    For each event, the module makes one row of the table of confirmations
    (`Explorer.Chain.Arbitrum.RollupBlockConfirmation`) with `top` and the lifecycle
    transaction of the event. The module gets the number of `top` from the indexed
    blocks. If the block is not indexed, it gets the number from the rollup RPC
    node.

    The table stores only `top` of each row. The order of `top` gives the rollup
    blocks of each row. Thus the module does not read the position of an event in
    the parent chain, and the result does not depend on the order of the events.
    Two events with the same `top` give one row: the import keeps the row that the
    code wrote first.

    If the highest `top` of the window is above the highest `top` in the database,
    the module marks the L2-to-L1 messages up to the new highest `top` as
    confirmed.

    The module does not write to the database. The caller imports the result
    together with its cursor in one database transaction, through
    `Indexer.Fetcher.Arbitrum.Utils.Db.Settlement.import_confirmations/3`.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  alias Explorer.Chain.Arbitrum

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Db.ParentChainTransactions, as: DbParentChainTransactions
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Events, as: EventsUtils

  require Logger

  @typedoc """
    The result of one window of the discovery, ready for the import:
    - `lifecycle_transactions`: the parent chain transactions of the events
    - `rollup_block_confirmations`: one row for each distinct `top` of the window
    - `messages`: the L2-to-L1 messages that become confirmed
    - `lowest_top`: the lowest `top` of the window, or `nil` if the window holds no event
  """
  @type discovered :: %{
          :lifecycle_transactions => [Arbitrum.LifecycleTransaction.to_import()],
          :rollup_block_confirmations => [Arbitrum.RollupBlockConfirmation.to_import()],
          :messages => [Arbitrum.Message.to_import()],
          :lowest_top => non_neg_integer() | nil
        }

  @typep l1_rpc_config :: %{
           :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
           :chunk_size => non_neg_integer(),
           :track_finalization => boolean(),
           optional(any()) => any()
         }

  @typep rollup_rpc_config :: %{
           :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
           optional(any()) => any()
         }

  @doc """
    Reads one window of the parent chain and prepares the confirmations that it holds.

    ## Parameters
    - `outbox_address`: The address of the Arbitrum outbox contract on the parent chain
    - `start_block`: The first parent chain block of the window
    - `end_block`: The last parent chain block of the window
    - `l1_rpc_config`: Configuration map for parent chain RPC interactions containing:
      * `:json_rpc_named_arguments` - Arguments for JSON RPC calls
      * `:chunk_size` - Size of chunks for batch processing
      * `:track_finalization` - Whether the confirmation transactions are imported as unfinalized
    - `rollup_rpc_config`: Configuration map for rollup RPC interactions containing:
      * `:json_rpc_named_arguments` - Arguments for JSON RPC calls

    ## Returns
    - The data of the window in the import format, see `t:discovered/0`.

    ## Raises
    - An error if an RPC request fails after the retries, or if the number of a
      rollup block cannot be found. The caller reads the same window again in its
      next run.
  """
  @spec perform(binary(), non_neg_integer(), non_neg_integer(), l1_rpc_config(), rollup_rpc_config()) :: discovered()
  def perform(outbox_address, start_block, end_block, l1_rpc_config, rollup_rpc_config) do
    logs =
      EventsUtils.get_logs_for_confirmations(
        start_block,
        end_block,
        outbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    handle_confirmations_from_logs(logs, l1_rpc_config, rollup_rpc_config)
  end

  # Prepares the confirmations of the given `SendRootUpdated` events.
  @spec handle_confirmations_from_logs([%{String.t() => any()}], l1_rpc_config(), rollup_rpc_config()) ::
          discovered()
  defp handle_confirmations_from_logs(logs, l1_rpc_config, rollup_rpc_config)

  defp handle_confirmations_from_logs([], _, _) do
    %{lifecycle_transactions: [], rollup_block_confirmations: [], messages: [], lowest_top: nil}
  end

  defp handle_confirmations_from_logs(logs, l1_rpc_config, rollup_rpc_config) do
    {tops_to_transactions, lifecycle_transactions_basic, blocks_requests} =
      parse_logs(logs, rollup_rpc_config)

    l1_blocks_to_ts =
      Rpc.execute_blocks_requests_and_get_ts(
        Map.values(blocks_requests),
        l1_rpc_config.json_rpc_named_arguments,
        l1_rpc_config.chunk_size
      )

    lifecycle_transactions =
      lifecycle_transactions_basic
      |> ArbitrumHelper.extend_lifecycle_transactions_with_ts_and_status(
        l1_blocks_to_ts,
        l1_rpc_config.track_finalization
      )
      |> DbParentChainTransactions.get_indices_for_l1_transactions()

    rollup_block_confirmations =
      Enum.map(tops_to_transactions, fn {top, l1_transaction_hash} ->
        %{top: top, confirmation_id: lifecycle_transactions[l1_transaction_hash].id}
      end)

    tops = Map.keys(tops_to_transactions)

    %{
      lifecycle_transactions: Map.values(lifecycle_transactions),
      rollup_block_confirmations: rollup_block_confirmations,
      messages: confirmed_l2_to_l1_messages(Enum.max(tops)),
      lowest_top: Enum.min(tops)
    }
  end

  # Parses the events to the tops that they confirm and to the basic descriptions
  # of their lifecycle transactions.
  #
  # Two events with the same `top` give one entry: the first event in the list
  # keeps it. Two events in one parent chain transaction give one lifecycle
  # transaction.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map of `top` to the hash of the lifecycle transaction, in bytes.
  #   - A map of basic-form lifecycle transactions keyed by the hash in bytes.
  #   - A map of RPC requests to fetch block data for these lifecycle transactions,
  #     keyed by the parent chain block number.
  @spec parse_logs([%{String.t() => any()}], rollup_rpc_config()) ::
          {
            %{non_neg_integer() => binary()},
            %{binary() => %{hash: binary(), block_number: non_neg_integer()}},
            %{non_neg_integer() => EthereumJSONRPC.Transport.request()}
          }
  defp parse_logs(logs, rollup_rpc_config) do
    Enum.reduce(logs, {%{}, %{}, %{}}, fn event, {tops, lifecycle_transactions, blocks_requests} ->
      rollup_block_hash = EventsUtils.send_root_updated_event_parse(event)
      top = rollup_block_number(rollup_block_hash, rollup_rpc_config)

      l1_transaction_hash_raw = event["transactionHash"]
      l1_transaction_hash = Rpc.string_hash_to_bytes_hash(l1_transaction_hash_raw)
      l1_block_number = quantity_to_integer(event["blockNumber"])

      log_info("Confirmation of the rollup block ##{top} (#{rollup_block_hash}) found in #{l1_transaction_hash_raw}")

      {
        Map.put_new(tops, top, l1_transaction_hash),
        Map.put(lifecycle_transactions, l1_transaction_hash, %{hash: l1_transaction_hash, block_number: l1_block_number}),
        Map.put(blocks_requests, l1_block_number, BlockByNumber.request(%{id: 0, number: l1_block_number}, false, true))
      }
    end)
  end

  # Gets the number of the rollup block from the indexed blocks, or from the rollup
  # RPC node if the block is not indexed.
  @spec rollup_block_number(String.t(), rollup_rpc_config()) :: non_neg_integer()
  defp rollup_block_number(rollup_block_hash, rollup_rpc_config) do
    case DbSettlement.rollup_block_hash_to_num(rollup_block_hash) do
      nil ->
        case Rpc.get_block_number_by_hash(rollup_block_hash, rollup_rpc_config.json_rpc_named_arguments) do
          nil -> raise "Cannot get the number of the rollup block #{rollup_block_hash}"
          number -> number
        end

      number ->
        number
    end
  end

  # Retrieves the L2-to-L1 messages that become confirmed with the new highest `top`.
  #
  # If the given `top` is not above the highest `top` in the database, no message
  # changes its status: the messages up to the highest `top` are confirmed already.
  @spec confirmed_l2_to_l1_messages(non_neg_integer()) :: [Arbitrum.Message.to_import()]
  defp confirmed_l2_to_l1_messages(highest_top_of_window) do
    if highest_top_of_window > DbSettlement.highest_confirmed_block(-1) do
      highest_top_of_window
      |> DbMessages.sent_l2_to_l1_messages()
      |> Enum.map(fn message -> Map.put(message, :status, :confirmed) end)
    else
      []
    end
  end
end
