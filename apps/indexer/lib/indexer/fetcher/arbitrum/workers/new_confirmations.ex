defmodule Indexer.Fetcher.Arbitrum.Workers.NewConfirmations do
  @moduledoc """
  TBD
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber
  alias Indexer.Helper, as: IndexerHelper

  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}

  alias Explorer.Chain

  require Logger

  # keccak256("SendRootUpdated(bytes32,bytes32)")
  @send_root_updated_event "0xb4df3847300f076a369cd76d2314b470a1194d9e8a6bb97f1860aee88a5f6748"

  defp get_logs_new_confirmations(start_block, end_block, outbox_address, json_rpc_named_arguments, cache \\ %{})
       when start_block <= end_block do
    {logs, new_cache} =
      case cache[{start_block, end_block}] do
        nil ->
          {:ok, rpc_logs} =
            IndexerHelper.get_logs(
              start_block,
              end_block,
              outbox_address,
              [@send_root_updated_event],
              json_rpc_named_arguments
            )

          {rpc_logs, Map.put(cache, {start_block, end_block}, rpc_logs)}

        cached_logs ->
          {cached_logs, cache}
      end

    if length(logs) > 0 do
      Logger.info("Found #{length(logs)} SendRootUpdated logs")
    end

    {logs, new_cache}
  end

  defp send_root_updated_event_parse(event) do
    [_, _, l2_block_hash] = event["topics"]

    l2_block_hash
  end

  defp parse_logs_for_new_confirmations(logs) do
    {rollup_block_to_l1_txs, lifecycle_txs, blocks_requests} =
      logs
      |> Enum.reduce({%{}, %{}}, fn event, {lifecycle_txs, blocks_requests} ->
        rollup_block_hash = send_root_updated_event_parse(event)

        l1_tx_hash_raw = event["transactionHash"]
        l1_tx_hash = Rpc.strhash_to_byteshash(l1_tx_hash_raw)
        l1_blk_num = quantity_to_integer(event["blockNumber"])

        updated_block_to_txs =
          Map.put(
            lifecycle_txs,
            rollup_block_hash,
            %{l1_tx_hash: l1_tx_hash, l1_block_num: l1_blk_num}
          )

        updated_lifecycle_txs =
          Map.put(
            lifecycle_txs,
            l1_tx_hash,
            %{hash: l1_tx_hash, block: l1_blk_num}
          )

        updated_blocks_requests =
          Map.put(
            blocks_requests,
            l1_blk_num,
            BlockByNumber.request(%{id: 0, number: l1_blk_num}, false, true)
          )

        Logger.info("New confirmation for the rollup block #{rollup_block_hash} found in #{l1_tx_hash_raw}")

        {updated_block_to_txs, updated_lifecycle_txs, updated_blocks_requests}
      end)

    {rollup_block_to_l1_txs, lifecycle_txs, Map.values(blocks_requests)}
  end

  defp extend_lifecycle_txs_with_ts_and_status(lifecycle_txs, blocks_to_ts, track_finalization?) do
    lifecycle_txs
    |> Map.keys()
    |> Enum.reduce(%{}, fn tx_key, updated_txs ->
      Map.put(
        updated_txs,
        tx_key,
        Map.merge(lifecycle_txs[tx_key], %{
          timestamp: blocks_to_ts[lifecycle_txs[tx_key].block],
          status:
            if track_finalization? do
              :unfinalized
            else
              :finalized
            end
        })
      )
    end)
  end

  defp recover_block_number_by_hash(hash, json_rpc_named_arguments) do
    Logger.info("Try to recover the rollup block #{hash} number by RPC call")
    Rpc.get_block_number_by_hash(hash, json_rpc_named_arguments)
  end

  defp discover_rollup_blocks(rollup_blocks_to_l1_txs, rollup_json_rpc_named_arguments, outbox_config) do
    block_to_l1_txs =
      rollup_blocks_to_l1_txs
      |> Map.keys()
      |> Enum.reduce(%{}, fn block_hash, transformed ->
        # If blocks were not caught up yet by indexer but the batch was discovered
        # the block number will be requested from RPC
        rollup_block_num =
          Db.rollup_block_hash_to_num(block_hash, %{
            function: &recover_block_number_by_hash/2,
            params: [block_hash, rollup_json_rpc_named_arguments]
          })

        # Nil is applicable for the case when the batch has not been discovered yet,
        # it makes sense to skip this block so far
        case rollup_block_num do
          nil ->
            Logger.warning("The rollup block #{block_hash} did not found. Plan to skip the confirmations")
            transformed

          value ->
            Map.put(transformed, value, rollup_blocks_to_l1_txs[block_hash])
        end
      end)

    if Enum.empty?(block_to_l1_txs) do
      []
    else
      # Oldest (with the lowest number) block is first
      rollup_block_numbers = Enum.sort(Map.keys(block_to_l1_txs), :asc)

      rollup_block_numbers
      |> Enum.reduce([], fn block_num, updated_rollup_blocks ->
        Logger.info("Attempting to mark all rollup blocks including ##{block_num} and lower as confirmed")

        {_, confirmed_blocks} =
          discover_rollup_blocks_belonging_to_one_confirmation(
            block_num,
            block_to_l1_txs[block_num],
            outbox_config,
            rollup_json_rpc_named_arguments
          )

        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        if length(confirmed_blocks) > 0 do
          Logger.info("Found #{length(confirmed_blocks)} confirmed blocks")

          add_confirm_transaction(confirmed_blocks, block_to_l1_txs[block_num].l1_tx_hash) ++
            updated_rollup_blocks
        else
          Logger.info("Either no unconfirmed blocks found or DB inconsistency error discovered")
          []
        end
      end)
    end
  end

  defp add_confirm_transaction(block_descriptions_list, confirm_tx_hash) do
    block_descriptions_list
    |> Enum.reduce([], fn block_descr, updated ->
      new_block_descr =
        block_descr
        |> Map.put(:confirm_transaction, confirm_tx_hash)

      [new_block_descr | updated]
    end)
  end

  defp discover_rollup_blocks__get_batch(rollup_block_num) do
    # Generally if batch is nil it means either
    # - a batch to a rollup block association is not found, not recoverable
    # - a rollup block is not found, the corresponding batch is not handled yet. It is possible
    #   because the method can be called for guessed block number rather than received from
    #   the batch description or from blocks list received after a batch handling. In this case
    #   the confirmation must be postponed until the corresponding batch is handled.
    batch = Db.get_batch_by_rollup_block_num(rollup_block_num)

    if batch != nil do
      Logger.info(
        "Attempt to identify which blocks of the batch ##{batch.number} within ##{batch.start_block}..##{rollup_block_num} are confirmed"
      )

      {:ok, batch}
    else
      Logger.warning(
        "Batch where the block ##{rollup_block_num} was included is not found, skipping this blocks and lower"
      )

      {:error, []}
    end
  end

  defp discover_rollup_blocks__get_unconfirmed_rollup_blocks(batch, rollup_block_num) do
    unconfirmed_rollup_blocks = Db.unconfirmed_rollup_blocks(batch.start_block, rollup_block_num)

    if Enum.empty?(unconfirmed_rollup_blocks) do
      # Blocks are not found only in case when all blocks in the batch confirmed
      # or in case when Chain.Block for block in the batch are not received yet

      if Db.count_confirmed_rollup_blocks_in_batch(batch.number) == batch.end_block - batch.start_block + 1 do
        Logger.info("No unconfirmed blocks in the batch #{batch.number}")
        {:ok, []}
      else
        Logger.warning("Seems that the batch #{batch.number} was not fully synced. Skipping its blocks")
        {:error, []}
      end
    else
      {:ok, unconfirmed_rollup_blocks}
    end
  end

  defp discover_rollup_blocks__check_confirmed_blocks_in_batch(
         rollup_block_num,
         unconfirmed_rollup_blocks_length,
         batch,
         confirmation_desc,
         outbox_config,
         rollup_json_rpc_named_arguments,
         cache
       ) do
    # Before examination of confirmed blocks exact amount found, check whether
    # the blocks from this batch covered by earlier confirmation don't accounted in DB
    {block?, new_cache} =
      check_if_batch_confirmed(batch, confirmation_desc, outbox_config, rollup_json_rpc_named_arguments, cache)

    if block? == rollup_block_num do
      Logger.info("All the blocks in the batch ##{batch.number} have been already confirmed by another transaction")
      {:ok, []}
    else
      first_unconfirmed_block_in_batch =
        case block? do
          nil ->
            batch.start_block

          value ->
            Logger.info("Blocks up to ##{value} of the batch have been already confirmed by another transaction")
            value + 1
        end

      if unconfirmed_rollup_blocks_length == rollup_block_num - first_unconfirmed_block_in_batch + 1 do
        {:ok, {first_unconfirmed_block_in_batch, new_cache}}
      else
        # The case when there is a gap in the blocks range is possible when there is
        # a DB inconsistency. From another side, the case when the confirmation is for blocks
        # in two batches -- one batch has been already indexed, another one has not been yet.
        # Both cases should be handled in the same way - this confirmation must be postponed
        # until the case resolution.
        Logger.warning(
          "Only #{unconfirmed_rollup_blocks_length} of #{rollup_block_num - first_unconfirmed_block_in_batch + 1} blocks found. Skipping the blocks from the batch #{batch.number}"
        )

        {:error, []}
      end
    end
  end

  defp discover_rollup_blocks__check_consecutive_rollup_blocks(unconfirmed_rollup_blocks, batch_number) do
    if consecutive_rollup_blocks?(unconfirmed_rollup_blocks) do
      true
    else
      # The case when there is a gap in the blocks range is possible when there is
      # a DB inconsistency. From another side, the case when the confirmation is for blocks
      # in two batches -- one batch has been already indexed, another one has not been yet.
      # Both cases should be handled in the same way - this confirmation must be postponed
      # until the case resolution.
      Logger.warning("Skipping the blocks from the batch #{batch_number}")
      {:error, []}
    end
  end

  defp discover_rollup_blocks_belonging_to_one_confirmation(
         rollup_block_num,
         confirmation_desc,
         outbox_config,
         rollup_json_rpc_named_arguments,
         cache \\ %{}
       ) do
    with {:ok, batch} <- discover_rollup_blocks__get_batch(rollup_block_num),
         {:ok, unconfirmed_rollup_blocks} when unconfirmed_rollup_blocks != [] <-
           discover_rollup_blocks__get_unconfirmed_rollup_blocks(batch, rollup_block_num),
         # It is not the issue to request logs for the first call of discover_rollup_blocks_belonging_to_one_confirmation
         # since we need to make sure that there is no another confirmation for part of the blocks of the batch
         {:ok, {first_unconfirmed_block, new_cache}} <-
           discover_rollup_blocks__check_confirmed_blocks_in_batch(
             rollup_block_num,
             length(unconfirmed_rollup_blocks),
             batch,
             confirmation_desc,
             outbox_config,
             rollup_json_rpc_named_arguments,
             cache
           ),
         true <- discover_rollup_blocks__check_consecutive_rollup_blocks(unconfirmed_rollup_blocks, batch.number) do
      if List.first(unconfirmed_rollup_blocks).block_num == batch.start_block do
        Logger.info("End of the batch #{batch.number} discovered, moving to the previous batch")

        {status, updated_rollup_blocks} =
          discover_rollup_blocks_belonging_to_one_confirmation(
            first_unconfirmed_block - 1,
            confirmation_desc,
            outbox_config,
            rollup_json_rpc_named_arguments,
            new_cache
          )

        case status do
          :error -> {:error, []}
          # updated_rollup_blocks will contain either [] if the previous batch already confirmed
          # or list of unconfirmed blocks of all previous unconfirmed batches
          :ok -> {:ok, unconfirmed_rollup_blocks ++ updated_rollup_blocks}
        end
      else
        Logger.info("All unconfirmed blocks in the batch ##{batch.number} found")
        {:ok, unconfirmed_rollup_blocks}
      end
    end
  end

  defp consecutive_rollup_blocks?(blocks) do
    {_, status} =
      Enum.reduce_while(blocks, {nil, false}, fn block, {prev, _} ->
        case prev do
          nil ->
            {:cont, {block.block_num, true}}

          value ->
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            if block.block_num - 1 == value do
              {:cont, {block.block_num, true}}
            else
              Logger.warning("A gap between blocks ##{value} and ##{block.block_num} found")
              {:halt, {block.block_num, false}}
            end
        end
      end)

    status
  end

  defp check_if_batch_confirmed(batch, confirmation_desc, l1_outbox_config, rollup_json_rpc_named_arguments, cache) do
    Logger.info(
      "Use L1 blocks #{batch.commit_transaction.block}..#{confirmation_desc.l1_block_num - 1} to look for a rollup block confirmation within #{batch.start_block}..#{batch.end_block} of ##{batch.number}"
    )

    l1_blocks_pairs_to_get_logs(
      batch.commit_transaction.block,
      confirmation_desc.l1_block_num - 1,
      l1_outbox_config.logs_block_range
    )
    |> Enum.reduce_while({nil, cache}, fn {log_start, log_end}, {_na, updated_cache} ->
      # credo:disable-for-previous-line Credo.Check.Refactor.PipeChainStart
      {latest_block_confirmed, new_cache} =
        do_check_if_batch_confirmed(
          {batch.start_block, batch.end_block},
          {log_start, log_end},
          l1_outbox_config,
          rollup_json_rpc_named_arguments,
          updated_cache
        )

      case latest_block_confirmed do
        nil ->
          {:cont, {nil, new_cache}}

        previous_confirmed_rollup_block ->
          Logger.info("Confirmed block ##{previous_confirmed_rollup_block} for the batch found")
          {:halt, {previous_confirmed_rollup_block, new_cache}}
      end
    end)
  end

  defp do_check_if_batch_confirmed(
         {rollup_start_block, rollup_end_block},
         {log_start, log_end},
         l1_outbox_config,
         rollup_json_rpc_named_arguments,
         cache
       ) do
    {logs, new_cache} =
      get_logs_new_confirmations(
        log_start,
        log_end,
        l1_outbox_config.outbox_address,
        l1_outbox_config.json_rpc_named_arguments,
        cache
      )

    latest_block_confirmed =
      logs
      |> Enum.reduce_while(nil, fn event, _acc ->
        Logger.info("Examining the transaction #{event["transactionHash"]}")
        rollup_block_hash = send_root_updated_event_parse(event)

        rollup_block_num =
          Db.rollup_block_hash_to_num(rollup_block_hash, %{
            function: &recover_block_number_by_hash/2,
            params: [rollup_block_hash, rollup_json_rpc_named_arguments]
          })

        if rollup_block_num >= rollup_start_block and rollup_block_num <= rollup_end_block do
          Logger.info("The rollup block ##{rollup_block_num} within the range")
          {:halt, rollup_block_num}
        else
          Logger.info("The rollup block ##{rollup_block_num} outside of the range")
          {:cont, nil}
        end
      end)

    {latest_block_confirmed, new_cache}
  end

  defp l1_blocks_pairs_to_get_logs(start, finish, max_range) do
    # credo:disable-for-lines:9 Credo.Check.Refactor.PipeChainStart
    Stream.unfold(finish, fn cur_finish ->
      if cur_finish < start do
        nil
      else
        cur_start = max(cur_finish - max_range + 1, start)
        {{cur_start, cur_finish}, cur_start - 1}
      end
    end)
    |> Enum.to_list()
  end

  defp take_lifecycle_txs_for_confirmed_blocks(confirmed_rollup_blocks, lifecycle_txs) do
    confirmed_rollup_blocks
    |> Enum.reduce(%{}, fn block_descr, updated_txs ->
      confirmation_tx_hash = block_descr.confirm_transaction

      case updated_txs[confirmation_tx_hash] do
        nil -> Map.put(updated_txs, confirmation_tx_hash, lifecycle_txs[confirmation_tx_hash])
        _ -> updated_txs
      end
    end)
  end

  defp finalize_lifecycle_txs_and_confirmed_blocks(
         basic_lifecycle_txs,
         confirmed_rollup_blocks,
         l1_blocks_requests,
         %{
           json_rpc_named_arguments: l1_json_rpc_named_arguments,
           chunk_size: l1_chunk_size,
           track_finalization: track_finalization?
         } = _l1_rpc_config
       ) do
    blocks_to_ts =
      Rpc.execute_blocks_requests_and_get_ts(l1_blocks_requests, l1_json_rpc_named_arguments, l1_chunk_size)

    lifecycle_txs =
      basic_lifecycle_txs
      |> extend_lifecycle_txs_with_ts_and_status(blocks_to_ts, track_finalization?)
      |> Db.get_indices_for_l1_transactions()

    {updated_rollup_blocks, highest_confirmed_block_number} =
      confirmed_rollup_blocks
      |> Enum.reduce({[], nil}, fn block, {updated_list, highest_confirmed} ->
        chosen_highest_confirmed = max(highest_confirmed, block.block_num)

        updated_block =
          block
          |> Map.put(:confirm_id, lifecycle_txs[block.confirm_transaction].id)
          |> Map.drop([:block_num, :confirm_transaction])

        {[updated_block | updated_list], chosen_highest_confirmed}
      end)

    {Map.values(lifecycle_txs), updated_rollup_blocks, highest_confirmed_block_number}
  end

  defp get_confirmed_l2_to_l1_messages(highest_confirmed_block_number) do
    Db.unconfirmed_l2_to_l1_messages(highest_confirmed_block_number)
    |> Enum.map(fn tx ->
      # credo:disable-for-previous-line Credo.Check.Refactor.PipeChainStart
      Map.put(tx, :status, :confirmed)
    end)
  end

  defp handle_confirmations_from_logs([], _, _, _) do
    {[], [], []}
  end

  defp handle_confirmations_from_logs(
         logs,
         l1_rpc_config,
         rollup_rpc_config,
         outbox_address
       ) do
    {rollup_blocks_to_l1_txs, lifecycle_txs_basic, blocks_requests} = parse_logs_for_new_confirmations(logs)

    rollup_blocks =
      discover_rollup_blocks(
        rollup_blocks_to_l1_txs,
        rollup_rpc_config.json_rpc_named_arguments,
        %{
          json_rpc_named_arguments: l1_rpc_config.json_rpc_named_arguments,
          logs_block_range: l1_rpc_config.logs_block_range,
          outbox_address: outbox_address
        }
      )

    applicable_lifecycle_txs = take_lifecycle_txs_for_confirmed_blocks(rollup_blocks, lifecycle_txs_basic)

    if Enum.empty?(applicable_lifecycle_txs) do
      {[], [], []}
    else
      {lifecycle_txs, rollup_blocks, highest_confirmed_block_number} =
        finalize_lifecycle_txs_and_confirmed_blocks(
          applicable_lifecycle_txs,
          rollup_blocks,
          blocks_requests,
          l1_rpc_config
        )

      # Drawback of marking messages as confirmed during a new confirmation handling
      # is that the status change could become stuck if confirmations are not handled.
      # For example, due to DB inconsistency: some blocks/batches are missed.
      confirmed_txs = get_confirmed_l2_to_l1_messages(highest_confirmed_block_number)

      {lifecycle_txs, rollup_blocks, confirmed_txs}
    end
  end

  @doc """
  TBD
  """
  def discover(
        outbox_address,
        start_block,
        end_block,
        l1_rpc_config,
        rollup_rpc_config
      ) do
    {logs, _} =
      get_logs_new_confirmations(
        start_block,
        end_block,
        outbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    {lifecycle_txs, rollup_blocks, confirmed_txs} =
      handle_confirmations_from_logs(
        logs,
        l1_rpc_config,
        rollup_rpc_config,
        outbox_address
      )

    {:ok, _} =
      Chain.import(%{
        arbitrum_lifecycle_transactions: %{params: lifecycle_txs},
        arbitrum_batch_blocks: %{params: rollup_blocks},
        arbitrum_messages: %{params: confirmed_txs},
        timeout: :infinity
      })
  end
end
