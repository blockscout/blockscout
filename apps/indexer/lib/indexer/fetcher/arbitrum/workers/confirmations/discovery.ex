defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery do
  @moduledoc """
    Handles the discovery and processing of rollup block confirmations in Arbitrum.

    This module processes confirmations of rollup blocks by analyzing `SendRootUpdated` events
    from the Arbitrum outbox contract on the parent chain. Each `SendRootUpdated` event
    indicates a top confirmed rollup block, implying that all rollup blocks with lower numbers
    are also confirmed.

    The confirmation process follows these key steps:
    1. Fetches `SendRootUpdated` event logs from the parent chain within the specified block range
    2. For each event, identifies the top confirmed rollup block and all unconfirmed blocks
       below it up to the previous confirmation or the chain's initial block
    3. Updates the status of the identified blocks and their associated L2-to-L1 messages
    4. Imports the confirmation data

    For example, if there are two confirmations where the earlier one points to block N and
    the later to block M (where M > N), the module links blocks from N+1 to M to the later
    confirmation. This sequential handling preserves the confirmation history, allowing each
    block to be associated with its specific confirmation transaction.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Db.ParentChainTransactions, as: DbParentChainTransactions
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Events, as: EventsUtils
  alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.RollupBlocks

  require Logger

  @doc """
    Discovers and processes new confirmations of rollup blocks within a specified parent chain
    block range.

    Fetches logs from the parent chain to identify new confirmations of rollup blocks, processes
    these confirmations to update block statuses, and marks relevant L2-to-L1 messages as
    confirmed. As the transaction on the parent chain containing the confirmation is considered
    a lifecycle transaction, the function imports it along with updated rollup blocks and
    cross-chain messages into the database in a single transaction.

    ## Parameters
    - `outbox_address`: The address of the Arbitrum outbox contract on parent chain
    - `start_block`: The parent chain block number to start fetching logs from
    - `end_block`: The parent chain block number to stop fetching logs at
    - `l1_rpc_config`: Configuration map for parent chain RPC interactions containing:
      * `:json_rpc_named_arguments` - Arguments for JSON RPC calls
      * `:logs_block_range` - Maximum block range for log requests
      * `:chunk_size` - Size of chunks for batch processing
      * `:finalized_confirmations` - Whether to track finalization status
    - `rollup_first_block`: The lowest block number of the L2 chain to consider

    ## Returns
    - `:ok` if all confirmations were processed successfully
    - `:confirmation_missed` if some confirmations could not be processed
  """
  @spec perform(
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :logs_block_range => non_neg_integer(),
            :chunk_size => non_neg_integer(),
            :finalized_confirmations => boolean(),
            optional(any()) => any()
          },
          non_neg_integer()
        ) :: :ok | :confirmation_missed
  def perform(
        outbox_address,
        start_block,
        end_block,
        l1_rpc_config,
        rollup_first_block
      ) do
    {logs, _} =
      EventsUtils.get_logs_for_confirmations(
        start_block,
        end_block,
        outbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    {retcode, {lifecycle_transactions, rollup_blocks, confirmed_transactions}} =
      handle_confirmations_from_logs(
        logs,
        l1_rpc_config,
        outbox_address,
        rollup_first_block
      )

    {:ok, _} =
      Chain.import(%{
        arbitrum_lifecycle_transactions: %{params: lifecycle_transactions},
        arbitrum_batch_blocks: %{params: rollup_blocks},
        arbitrum_messages: %{params: confirmed_transactions},
        timeout: :infinity
      })

    retcode
  end

  # Processes logs to handle confirmations for rollup blocks.
  #
  # This function analyzes logs containing `SendRootUpdated` events with information
  # about the confirmations up to a specific point in time, avoiding the reprocessing
  # of confirmations already known in the database. It identifies the ranges of
  # rollup blocks covered by the confirmations and constructs lifecycle transactions
  # linked to these confirmed blocks. Considering the highest confirmed rollup block
  # number, it discovers L2-to-L1 messages that have been committed and updates their
  # status to confirmed. The confirmations already processed are also updated to
  # ensure the correct L1 block number and timestamp, which may have changed due to
  # re-orgs. Lists of confirmed rollup blocks, lifecycle transactions, and confirmed
  # messages are prepared for database import.
  #
  # ## Parameters
  # - `logs`: Log entries representing `SendRootUpdated` events.
  # - `l1_rpc_config`: Configuration for L1 RPC calls.
  # - `outbox_address`: The address of the Arbitrum outbox contract.
  # - `rollup_first_block`: The block number limiting the lowest indexed block of
  #   the chain.
  #
  # ## Returns
  # - `{retcode, {lifecycle_transactions, rollup_blocks, confirmed_transactions}}` where
  #   - `retcode` is either `:ok` or `:confirmation_missed`
  #   - `lifecycle_transactions` is a list of lifecycle transactions confirming blocks in the
  #     rollup
  #   - `rollup_blocks` is a list of rollup blocks associated with the corresponding
  #     lifecycle transactions
  #   - `confirmed_messages` is a list of L2-to-L1 messages identified up to the
  #     highest confirmed block number, to be imported with the new status
  #     `:confirmed`
  @spec handle_confirmations_from_logs(
          [%{String.t() => any()}],
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :logs_block_range => non_neg_integer(),
            :chunk_size => non_neg_integer(),
            :finalized_confirmations => boolean(),
            optional(any()) => any()
          },
          binary(),
          non_neg_integer()
        ) ::
          {:ok | :confirmation_missed,
           {[Arbitrum.LifecycleTransaction.to_import()], [Arbitrum.BatchBlock.to_import()],
            [Arbitrum.Message.to_import()]}}
  defp handle_confirmations_from_logs(logs, l1_rpc_config, outbox_address, rollup_first_block)

  defp handle_confirmations_from_logs([], _, _, _) do
    {:ok, {[], [], []}}
  end

  defp handle_confirmations_from_logs(
         logs,
         l1_rpc_config,
         outbox_address,
         rollup_first_block
       ) do
    # On this step there could be lifecycle transactions for the rollup blocks which are
    # already confirmed. It is only possible in the scenario when the confirmation
    # discovery process does not wait for the safe L1 block. In this case:
    # - rollup_blocks_to_l1_transactions will not contain the corresponding block hash associated
    #   with the L1 transaction hash
    # - lifecycle_transactions_basic will contain all discovered lifecycle transactions
    # - blocks_requests will contain all requests to fetch block data for the lifecycle
    #   transactions
    # - existing_lifecycle_transactions will contain lifecycle transactions which was found in the
    #   logs and already imported into the database.
    {rollup_blocks_to_l1_transactions, lifecycle_transactions_basic, blocks_requests, existing_lifecycle_transactions} =
      parse_logs_for_new_confirmations(logs)

    # This step must be run only if there are hashes of the confirmed rollup blocks
    # in rollup_blocks_to_l1_transactions - when there are newly discovered confirmations.
    rollup_blocks =
      if Enum.empty?(rollup_blocks_to_l1_transactions) do
        []
      else
        RollupBlocks.extend_confirmations(
          rollup_blocks_to_l1_transactions,
          %{
            json_rpc_named_arguments: l1_rpc_config.json_rpc_named_arguments,
            logs_block_range: l1_rpc_config.logs_block_range,
            outbox_address: outbox_address
          },
          rollup_first_block
        )
      end

    # Will return %{} if there are no new confirmations
    applicable_lifecycle_transactions =
      take_lifecycle_transactions_for_confirmed_blocks(rollup_blocks, lifecycle_transactions_basic)

    # Will contain :ok if no new confirmations are found
    retcode =
      if Enum.count(lifecycle_transactions_basic) !=
           Enum.count(applicable_lifecycle_transactions) + length(existing_lifecycle_transactions) do
        :confirmation_missed
      else
        :ok
      end

    if Enum.empty?(applicable_lifecycle_transactions) and existing_lifecycle_transactions == [] do
      # Only if both new confirmations and already existing confirmations are empty
      {retcode, {[], [], []}}
    else
      l1_blocks_to_ts =
        Rpc.execute_blocks_requests_and_get_ts(
          blocks_requests,
          l1_rpc_config.json_rpc_named_arguments,
          l1_rpc_config.chunk_size
        )

      # The lifecycle transactions for the new confirmations are finalized here.
      {lifecycle_transactions_for_new_confirmations, rollup_blocks, highest_confirmed_block_number} =
        finalize_lifecycle_transactions_and_confirmed_blocks(
          applicable_lifecycle_transactions,
          rollup_blocks,
          l1_blocks_to_ts,
          l1_rpc_config.track_finalization
        )

      # The lifecycle transactions for the already existing confirmations are updated here
      # to ensure correct L1 block number and timestamp that could appear due to re-orgs.
      lifecycle_transactions =
        lifecycle_transactions_for_new_confirmations ++
          update_lifecycle_transactions_for_new_blocks(
            existing_lifecycle_transactions,
            lifecycle_transactions_basic,
            l1_blocks_to_ts
          )

      # Drawback of marking messages as confirmed during a new confirmation handling
      # is that the status change could become stuck if confirmations are not handled.
      # For example, due to DB inconsistency: some blocks/batches are missed.
      confirmed_messages = get_confirmed_l2_to_l1_messages(highest_confirmed_block_number)

      {retcode, {lifecycle_transactions, rollup_blocks, confirmed_messages}}
    end
  end

  # Parses logs to extract new confirmations for rollup blocks and prepares related data.
  #
  # This function processes `SendRootUpdated` event logs. For each event which
  # was not processed before, it maps the hash of the top confirmed rollup block
  # provided in the event to the confirmation description, containing the L1
  # transaction hash and block number. It also prepares a set of lifecycle
  # transactions in basic form, the set of lifecycle transaction already
  # existing in the database and block requests to later fetch timestamps for
  # the corresponding lifecycle transactions.
  #
  # ## Parameters
  # - `logs`: A list of log entries representing `SendRootUpdated` events.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map associating rollup block hashes with their confirmation descriptions.
  #   - A map of basic-form lifecycle transactions keyed by L1 transaction hash.
  #   - A list of RPC requests to fetch block data for these lifecycle transactions.
  #   - A list of discovered lifecycle transactions which are already in the
  #     database. Each transaction is compatible with the database import operation.
  @spec parse_logs_for_new_confirmations([%{String.t() => any()}]) ::
          {
            %{binary() => %{l1_transaction_hash: binary(), l1_block_num: non_neg_integer()}},
            %{binary() => %{hash: binary(), block_number: non_neg_integer()}},
            [EthereumJSONRPC.Transport.request()],
            [Arbitrum.LifecycleTransaction.to_import()]
          }
  defp parse_logs_for_new_confirmations(logs) do
    transaction_hashes =
      logs
      |> Enum.reduce(%{}, fn event, acc ->
        l1_transaction_hash_raw = event["transactionHash"]
        Map.put_new(acc, l1_transaction_hash_raw, Rpc.string_hash_to_bytes_hash(l1_transaction_hash_raw))
      end)

    existing_lifecycle_transactions =
      transaction_hashes
      |> Map.values()
      |> DbParentChainTransactions.lifecycle_transactions()
      |> Enum.reduce(%{}, fn transaction, acc ->
        Map.put(acc, transaction.hash, transaction)
      end)

    {rollup_block_to_l1_transactions, lifecycle_transactions, blocks_requests} =
      logs
      |> Enum.reduce({%{}, %{}, %{}}, fn event, {block_to_transactions, lifecycle_transactions, blocks_requests} ->
        rollup_block_hash = EventsUtils.send_root_updated_event_parse(event)

        l1_transaction_hash_raw = event["transactionHash"]
        l1_transaction_hash = transaction_hashes[l1_transaction_hash_raw]
        l1_blk_num = quantity_to_integer(event["blockNumber"])

        # There is no need to include the found block hash for the consequent confirmed
        # blocks discovery step since it is assumed that already existing lifecycle
        # transactions are already linked with the corresponding rollup blocks.
        updated_block_to_transactions =
          if Map.has_key?(existing_lifecycle_transactions, l1_transaction_hash) do
            block_to_transactions
          else
            Map.put(
              block_to_transactions,
              rollup_block_hash,
              %{l1_transaction_hash: l1_transaction_hash, l1_block_num: l1_blk_num}
            )
          end

        updated_lifecycle_transactions =
          Map.put(
            lifecycle_transactions,
            l1_transaction_hash,
            %{hash: l1_transaction_hash, block_number: l1_blk_num}
          )

        updated_blocks_requests =
          Map.put(
            blocks_requests,
            l1_blk_num,
            BlockByNumber.request(%{id: 0, number: l1_blk_num}, false, true)
          )

        log_info("New confirmation for the rollup block #{rollup_block_hash} found in #{l1_transaction_hash_raw}")

        {updated_block_to_transactions, updated_lifecycle_transactions, updated_blocks_requests}
      end)

    {rollup_block_to_l1_transactions, lifecycle_transactions, Map.values(blocks_requests),
     Map.values(existing_lifecycle_transactions)}
  end

  # Selects lifecycle transaction descriptions used for confirming a given list of rollup blocks.
  @spec take_lifecycle_transactions_for_confirmed_blocks(
          [Arbitrum.BatchBlock.to_import()],
          %{binary() => %{hash: binary(), block_number: non_neg_integer()}}
        ) :: %{binary() => %{hash: binary(), block_number: non_neg_integer()}}
  defp take_lifecycle_transactions_for_confirmed_blocks(confirmed_rollup_blocks, lifecycle_transactions) do
    confirmed_rollup_blocks
    |> Enum.reduce(%{}, fn block_descr, updated_transactions ->
      confirmation_transaction_hash = block_descr.confirmation_transaction

      Map.put_new(
        updated_transactions,
        confirmation_transaction_hash,
        lifecycle_transactions[confirmation_transaction_hash]
      )
    end)
  end

  # Finalizes lifecycle transaction descriptions and establishes database-ready links
  # between confirmed rollup blocks and their corresponding lifecycle transactions.
  #
  # This function executes chunked requests to L1 to retrieve block timestamps, which,
  # along with the finalization flag, are then used to finalize the lifecycle
  # transaction descriptions. Each entity in the list of blocks, which needs to be
  # confirmed, is updated with the associated lifecycle transaction IDs and prepared
  # for import.
  #
  # ## Parameters
  # - `basic_lifecycle_transactions`: The initial list of partially filled lifecycle transaction
  #                          descriptions.
  # - `confirmed_rollup_blocks`: Rollup blocks to be considered as confirmed.
  # - `l1_blocks_requests`: RPC requests of `eth_getBlockByNumber` to fetch L1 block data
  #                         for use in the lifecycle transaction descriptions.
  # - A map containing L1 RPC configuration such as JSON RPC arguments, chunk size,
  #   and a flag indicating whether to track the finalization of transactions.
  #
  # ## Returns
  # - A tuple containing:
  #   - The map of lifecycle transactions where each transaction is ready for import.
  #   - The list of confirmed rollup blocks, ready for import.
  #   - The highest confirmed block number processed during this run.
  @spec finalize_lifecycle_transactions_and_confirmed_blocks(
          %{binary() => %{hash: binary(), block_number: non_neg_integer()}},
          [Arbitrum.BatchBlock.to_import()],
          %{required(EthereumJSONRPC.block_number()) => DateTime.t()},
          boolean()
        ) :: {
          [Arbitrum.LifecycleTransaction.to_import()],
          [Arbitrum.BatchBlock.to_import()],
          integer()
        }
  defp finalize_lifecycle_transactions_and_confirmed_blocks(
         basic_lifecycle_transactions,
         confirmed_rollup_blocks,
         l1_blocks_to_ts,
         track_finalization?
       )

  defp finalize_lifecycle_transactions_and_confirmed_blocks(basic_lifecycle_transactions, _, _, _)
       when map_size(basic_lifecycle_transactions) == 0 do
    {[], [], -1}
  end

  defp finalize_lifecycle_transactions_and_confirmed_blocks(
         basic_lifecycle_transactions,
         confirmed_rollup_blocks,
         l1_blocks_to_ts,
         track_finalization?
       ) do
    lifecycle_transactions =
      basic_lifecycle_transactions
      |> ArbitrumHelper.extend_lifecycle_transactions_with_ts_and_status(l1_blocks_to_ts, track_finalization?)
      |> DbParentChainTransactions.get_indices_for_l1_transactions()

    {updated_rollup_blocks, highest_confirmed_block_number} =
      confirmed_rollup_blocks
      |> Enum.reduce({[], -1}, fn block, {updated_list, highest_confirmed} ->
        chosen_highest_confirmed = max(highest_confirmed, block.block_number)

        updated_block =
          block
          |> Map.put(:confirmation_id, lifecycle_transactions[block.confirmation_transaction].id)
          |> Map.drop([:confirmation_transaction])

        {[updated_block | updated_list], chosen_highest_confirmed}
      end)

    {Map.values(lifecycle_transactions), updated_rollup_blocks, highest_confirmed_block_number}
  end

  # Updates lifecycle transactions with new L1 block numbers and timestamps which could appear due to re-orgs.
  #
  # ## Parameters
  # - `existing_commitment_transactions`: A list of existing confirmation transactions to be checked and updated.
  # - `transaction_to_l1_block`: A map from transaction hashes to their corresponding new L1 block numbers.
  # - `l1_block_to_ts`: A map from L1 block numbers to their corresponding new timestamps.
  #
  # ## Returns
  # - A list of updated confirmation transactions with new block numbers and timestamps.
  @spec update_lifecycle_transactions_for_new_blocks(
          [Arbitrum.LifecycleTransaction.to_import()],
          %{binary() => non_neg_integer()},
          %{non_neg_integer() => DateTime.t()}
        ) :: [Arbitrum.LifecycleTransaction.to_import()]
  defp update_lifecycle_transactions_for_new_blocks(
         existing_commitment_transactions,
         transaction_to_l1_block,
         l1_block_to_ts
       ) do
    existing_commitment_transactions
    |> Enum.reduce([], fn transaction, updated_transactions ->
      new_block_num = transaction_to_l1_block[transaction.hash].block_number
      new_ts = l1_block_to_ts[new_block_num]

      case ArbitrumHelper.compare_lifecycle_transaction_and_update(transaction, {new_block_num, new_ts}, "confirmation") do
        {:updated, updated_transaction} ->
          [updated_transaction | updated_transactions]

        _ ->
          updated_transactions
      end
    end)
  end

  # Retrieves committed L2-to-L1 messages up to specified block number and marks them as 'confirmed'.
  @spec get_confirmed_l2_to_l1_messages(integer()) :: [Arbitrum.Message.to_import()]
  defp get_confirmed_l2_to_l1_messages(block_number)

  defp get_confirmed_l2_to_l1_messages(-1) do
    []
  end

  defp get_confirmed_l2_to_l1_messages(block_number) do
    block_number
    |> DbMessages.sent_l2_to_l1_messages()
    |> Enum.map(fn transaction ->
      Map.put(transaction, :status, :confirmed)
    end)
  end
end
