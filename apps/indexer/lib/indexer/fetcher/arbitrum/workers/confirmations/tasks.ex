# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Tasks do
  @moduledoc """
    Handles the discovery of the confirmations of rollup blocks for an Arbitrum rollup.

    A confirmation is a `SendRootUpdated` event of the Arbitrum `Outbox` contract
    on the parent chain. The event confirms the rollup block that it names and all
    rollup blocks below it. The discovery writes one row for each event to the table
    of confirmations, see `Explorer.Chain.Arbitrum.RollupBlockConfirmation`.

    Two processes read the parent chain in windows. A window is a range of parent
    chain blocks, and its size is the limit of the RPC node for `eth_getLogs`.
    - The main process moves up the parent chain from its cursor. Its upper limit
      is the safe block if `finalized_confirmations` is `true`, or the latest block
      otherwise. In the second case, each window starts at the lower of the block
      after the cursor and the safe block. Thus the process reads the blocks above
      the safe block again, and a re-org of the parent chain does not lose an event.
    - The backfill process moves down the parent chain from its cursor. It stops
      when its cursor reaches `l1_rollup_init_block`, or when it finds an event with
      a `top` below the lowest rollup block that the instance indexes. In the
      second case, the events below confirm only the rollup blocks that the
      instance does not index.

    Each process keeps a cursor in the database: the number of the last parent
    chain block that the process read. The process writes its cursor after each
    window, in one database transaction with the rows of the window. At the first
    start, the start point of both processes is the parent chain block of the
    commitment of the latest batch. If `finalized_confirmations` is `true`, the
    start point is not above the safe block, because the backfill process reads
    a block only once. If no batch exists, the discovery waits.

    The main process does not start while the table of the confirmations is empty
    and the backfill cursor is above `l1_rollup_init_block`. Thus the first event
    that the backfill process finds confirms almost all indexed rollup blocks
    before the main process reads the head of the parent chain.

    The order of the events does not change the result. Thus the final table does
    not depend on which process found an event, or when.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1, log_warning: 1]

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery, as: ConfirmationsDiscovery
  alias Indexer.Helper, as: IndexerHelper

  require Logger

  @type new_confirmations_data_map :: %{
          :cursor => nil | non_neg_integer()
        }

  @type historical_confirmations_data_map :: %{
          :cursor => nil | non_neg_integer()
        }

  @typep confirmations_related_state :: %{
           :config => %{
             :l1_outbox_address => binary(),
             :l1_rollup_init_block => non_neg_integer(),
             :l1_rpc => %{
               :finalized_confirmations => boolean(),
               :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
               :logs_block_range => non_neg_integer(),
               :chunk_size => non_neg_integer(),
               :track_finalization => boolean(),
               optional(any()) => any()
             },
             :rollup_rpc => %{
               :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
               optional(any()) => any()
             },
             :rollup_first_block => non_neg_integer(),
             optional(any()) => any()
           },
           :task_data => %{
             :new_confirmations => new_confirmations_data_map(),
             :historical_confirmations => historical_confirmations_data_map(),
             optional(any()) => any()
           },
           optional(any()) => any()
         }

  @doc """
    Runs one window of the main process of the confirmations discovery.

    The function reads the cursors from the database at the first run, or computes
    the start point if no cursor exists. Then it reads the window above the main
    cursor, imports the confirmations of the window, and moves the cursor to the
    last block of the window.

    The function does nothing in these cases:
    - No batch exists, so the start point is unknown. The function writes a log
      message about it.
    - The table of the confirmations is empty and the backfill cursor is above
      `l1_rollup_init_block`. The main process waits for the backfill process.
    - The block after the cursor is above the upper limit of the parent chain.

    ## Parameters
    - `state`: A map containing:
      - `config`: Configuration map with the outbox address, the RPC settings, the
        first rollup block, and `l1_rollup_init_block`
      - `task_data`: Task-related data including the cursors of both processes

    ## Returns
    - `{:ok, new_state}`
  """
  @spec check_new(confirmations_related_state()) :: {:ok, confirmations_related_state()}
  def check_new(state) do
    case load_cursors(state) do
      {:ok, state} -> discover_new(state)
      {:no_batches, state} -> {:ok, state}
    end
  end

  @spec discover_new(confirmations_related_state()) :: {:ok, confirmations_related_state()}
  defp discover_new(
         %{
           config: %{
             l1_rpc: l1_rpc_config,
             l1_outbox_address: outbox_address,
             l1_rollup_init_block: l1_rollup_init_block,
             rollup_rpc: rollup_rpc_config
           },
           task_data: %{
             new_confirmations: %{cursor: cursor},
             historical_confirmations: %{cursor: backfill_cursor}
           }
         } = state
       ) do
    if backfill_cursor > l1_rollup_init_block and is_nil(DbSettlement.highest_confirmed_block(nil)) do
      log_info("New rollup confirmations discovery waits for the first confirmation of the historical discovery")
      {:ok, state}
    else
      {start_block, end_block} = new_confirmations_window(cursor, l1_rpc_config)

      if start_block <= end_block do
        log_info("Block range for new rollup confirmations discovery: #{start_block}..#{end_block}")

        discovered =
          ConfirmationsDiscovery.perform(outbox_address, start_block, end_block, l1_rpc_config, rollup_rpc_config)

        :ok = DbSettlement.import_confirmations(discovered, :main, end_block)

        {:ok, ArbitrumHelper.update_fetcher_task_data(state, :new_confirmations, %{cursor: end_block})}
      else
        {:ok, state}
      end
    end
  end

  # Computes the window of the main process above the cursor.
  #
  # If `finalized_confirmations` is `true`, the window starts after the cursor and
  # ends at the safe block. Otherwise, the window starts at the lower of the block
  # after the cursor and the safe block, and ends at the latest block. The safe
  # block is not more than `INDEXER_ARBITRUM_L1_FINALIZATION_THRESHOLD` blocks
  # below the latest block. Thus the window holds not more than `logs_block_range`
  # blocks and one `eth_getLogs` request reads it.
  @spec new_confirmations_window(non_neg_integer(), %{
          :finalized_confirmations => boolean(),
          :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
          :logs_block_range => non_neg_integer(),
          optional(any()) => any()
        }) :: {non_neg_integer(), non_neg_integer()}
  defp new_confirmations_window(cursor, l1_rpc_config) do
    {start_block, upper_block} =
      if l1_rpc_config.finalized_confirmations do
        # It makes sense to use "safe" here. Blocks are confirmed with delay in one week
        # (applicable for ArbitrumOne and Nova), so 10 mins delay is not significant.
        # By using "safe" we can avoid re-visiting the same blocks in case of reorgs.
        {safe_chain_block, _} = IndexerHelper.get_safe_block(l1_rpc_config.json_rpc_named_arguments)

        {cursor + 1, safe_chain_block}
      else
        # There are situations when it could be necessary to react on L1 confirmation
        # transactions earlier than the safe block. For example, for testnets.
        # Another situation when the rollup uses L1 RPC which does not support "safe"
        # block retrieval.
        # In both cases it is desired to re-visit some amount head blocks to ensure
        # that no confirmation is missed due to reorgs.
        {safe_block, latest_block} =
          Rpc.get_safe_and_latest_l1_blocks(l1_rpc_config.json_rpc_named_arguments, l1_rpc_config.logs_block_range)

        {min(cursor + 1, safe_block), latest_block}
      end

    {start_block, min(start_block + l1_rpc_config.logs_block_range - 1, upper_block)}
  end

  @doc """
    Runs one window of the backfill process of the confirmations discovery.

    The function reads the cursors from the database at the first run, or computes
    the start point if no cursor exists. Then it reads the window below the
    backfill cursor, imports the confirmations of the window, and moves the cursor
    to the first block of the window.

    If the window holds an event with a `top` below the lowest rollup block that
    the instance indexes, the function imports the event and sets the cursor to
    `l1_rollup_init_block`. The events below confirm only the rollup blocks that
    the instance does not index.

    The function does nothing if no batch exists, or if the cursor is at
    `l1_rollup_init_block` or below it. If no batch exists, the function returns
    the status `:no_batches`, so the caller can run the next check after a longer
    interval.

    ## Parameters
    - `state`: A map containing:
      - `config`: Configuration map with the outbox address, the RPC settings, the
        first rollup block, and `l1_rollup_init_block`
      - `task_data`: Task-related data including the cursors of both processes

    ## Returns
    - `{:ok, new_state}` after a window, or when the backfill is complete
    - `{:no_batches, state}` if no cursor and no batch exist
  """
  @spec check_historical(confirmations_related_state()) ::
          {:ok | :no_batches, confirmations_related_state()}
  def check_historical(state) do
    case load_cursors(state) do
      {:ok, state} -> discover_historical(state)
      {:no_batches, state} -> {:no_batches, state}
    end
  end

  @spec discover_historical(confirmations_related_state()) :: {:ok, confirmations_related_state()}
  defp discover_historical(
         %{
           config: %{
             l1_rpc: l1_rpc_config,
             l1_outbox_address: outbox_address,
             l1_rollup_init_block: l1_rollup_init_block,
             rollup_first_block: rollup_first_block,
             rollup_rpc: rollup_rpc_config
           },
           task_data: %{historical_confirmations: %{cursor: cursor}}
         } = state
       ) do
    if cursor <= l1_rollup_init_block do
      {:ok, state}
    else
      end_block = cursor - 1
      start_block = max(l1_rollup_init_block, cursor - l1_rpc_config.logs_block_range)

      log_info("Block range for historical rollup confirmations discovery: #{start_block}..#{end_block}")

      discovered =
        ConfirmationsDiscovery.perform(outbox_address, start_block, end_block, l1_rpc_config, rollup_rpc_config)

      new_cursor =
        if not is_nil(discovered.lowest_top) and discovered.lowest_top < rollup_first_block do
          log_info(
            "A confirmation of the rollup block ##{discovered.lowest_top} is below the first indexed rollup block, historical rollup confirmations discovery is complete"
          )

          l1_rollup_init_block
        else
          start_block
        end

      :ok = DbSettlement.import_confirmations(discovered, :backfill, new_cursor)

      {:ok, ArbitrumHelper.update_fetcher_task_data(state, :historical_confirmations, %{cursor: new_cursor})}
    end
  end

  @doc """
    Determines whether the backfill process of the confirmations discovery has completed.

    The process is complete when its cursor is at `l1_rollup_init_block` or below it.

    ## Parameters
    - `state`: A map containing the configuration and the task data with the cursor
      of the backfill process

    ## Returns
    - `true` if the cursor is known and at `l1_rollup_init_block` or below it
    - `false` otherwise
  """
  @spec historical_confirmations_discovery_completed?(confirmations_related_state()) :: boolean()
  def historical_confirmations_discovery_completed?(%{
        config: %{l1_rollup_init_block: l1_rollup_init_block},
        task_data: %{historical_confirmations: %{cursor: cursor}}
      })
      when not is_nil(cursor) do
    cursor <= l1_rollup_init_block
  end

  def historical_confirmations_discovery_completed?(_), do: false

  @doc """
    Determines the lowest parent chain block that can hold a confirmation of an indexed rollup block.

    A confirmation cannot come before its rollup block, and an execution of an
    L2-to-L1 message cannot come before the confirmation of its rollup block.
    Thus other historical discoveries use this block as their lower bound.

    The function gives the parent chain block of the confirmation that owns the
    first indexed rollup block in the table. While the backfill process runs, the
    backfill can find an earlier confirmation of this rollup block later. Thus the
    bound can move down while the backfill process runs, and it never moves up.
    A discovery that uses the bound must not stop at it before the backfill
    process is complete.

    If the table does not hold a confirmation of the first indexed rollup block,
    the function gives `l1_rollup_init_block` after the backfill process is
    complete, and `nil` while the backfill process runs. In the second case, the
    bound is unknown, and a discovery that uses it must wait.

    ## Parameters
    - `state`: A map containing the configuration with `l1_rollup_init_block` and
      `rollup_first_block`, and the task data with the cursor of the backfill process

    ## Returns
    - The number of the parent chain block
    - `nil` if the bound is unknown
  """
  @spec lowest_l1_block_for_confirmations(confirmations_related_state()) :: non_neg_integer() | nil
  def lowest_l1_block_for_confirmations(
        %{config: %{l1_rollup_init_block: l1_rollup_init_block, rollup_first_block: rollup_first_block}} = state
      ) do
    case DbSettlement.l1_block_of_confirmation_for_rollup_block(rollup_first_block) do
      nil ->
        if historical_confirmations_discovery_completed?(state), do: l1_rollup_init_block, else: nil

      l1_block_number ->
        l1_block_number
    end
  end

  # Loads the cursors of both processes into the state.
  #
  # The cursors come from the database. If the database has no cursors, the
  # function computes the start point with `start_point/1`. The function writes
  # both cursors before the first window. A restart does not compute the start
  # point again.
  #
  # ## Returns
  # - `{:ok, state}` with the cursors in the task data
  # - `{:no_batches, state}` if no cursor and no batch exist
  @spec load_cursors(confirmations_related_state()) ::
          {:ok, confirmations_related_state()} | {:no_batches, confirmations_related_state()}
  defp load_cursors(%{task_data: %{new_confirmations: %{cursor: cursor}}} = state) when not is_nil(cursor) do
    {:ok, state}
  end

  defp load_cursors(state) do
    case {DbSettlement.confirmations_cursor(:main), DbSettlement.confirmations_cursor(:backfill)} do
      {main_cursor, backfill_cursor} when not is_nil(main_cursor) and not is_nil(backfill_cursor) ->
        {:ok, put_cursors(state, main_cursor, backfill_cursor)}

      _ ->
        case start_point(state) do
          nil ->
            log_warning("Rollup confirmations discovery waits for the first batch to find its start point")
            {:no_batches, state}

          start_point ->
            log_info("Rollup confirmations discovery starts from the parent chain block #{start_point}")
            :ok = DbSettlement.initialize_confirmations_cursors(start_point)
            {:ok, put_cursors(state, start_point - 1, start_point)}
        end
    end
  end

  # Computes the start point of both processes.
  #
  # The start point is the parent chain block of the commitment of the latest
  # batch. If `finalized_confirmations` is `true`, the main process reads only
  # the blocks up to the safe block, and the backfill process reads each block
  # once. A re-org, a change of the recent blocks of the parent chain, can move
  # a block above the safe block. Thus the start point is the lower of the
  # commitment block and the safe block in this case. The start point is not
  # below `l1_rollup_init_block`.
  #
  # ## Returns
  # - The number of the parent chain block, or `nil` if no batch exists
  @spec start_point(confirmations_related_state()) :: non_neg_integer() | nil
  defp start_point(%{config: %{l1_rpc: l1_rpc_config, l1_rollup_init_block: l1_rollup_init_block}}) do
    case DbSettlement.l1_block_of_latest_committed_batch() do
      nil ->
        nil

      commitment_block ->
        upper_limit =
          if l1_rpc_config.finalized_confirmations do
            {safe_block, _} = IndexerHelper.get_safe_block(l1_rpc_config.json_rpc_named_arguments)
            safe_block
          else
            commitment_block
          end

        max(l1_rollup_init_block, min(commitment_block, upper_limit))
    end
  end

  @spec put_cursors(confirmations_related_state(), non_neg_integer(), non_neg_integer()) ::
          confirmations_related_state()
  defp put_cursors(state, main_cursor, backfill_cursor) do
    state
    |> ArbitrumHelper.update_fetcher_task_data(:new_confirmations, %{cursor: main_cursor})
    |> ArbitrumHelper.update_fetcher_task_data(:historical_confirmations, %{cursor: backfill_cursor})
  end
end
