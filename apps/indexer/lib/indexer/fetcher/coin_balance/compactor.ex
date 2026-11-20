# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.CoinBalance.Compactor do
  @moduledoc """
  Periodically deletes the coin balances that carry no balance change, following
  the chain head at a distance.

  A coin balance is written for every block an address is touched in, so a
  contract that is called in nearly every block gets a row per block although its
  balance almost never changes. Whether such a row is redundant cannot be told
  reliably when it is written: the blocks next to the chain head are imported
  concurrently and out of order, so a row of a lower block can still show up
  afterwards. This process therefore goes through the blocks in batches of
  `batch_size` blocks and leaves the decision on every row to
  `Explorer.Chain.Address.CoinBalance.delete_unchanged/3`. It never goes above
  any of these boundaries:

    * `Indexer.Block.Catchup.MissingRangesCollector.settled_block_number/0`:
      every block at or below it is either imported or recorded in
      `missing_block_ranges`. A block above it that failed to import is not
      recorded anywhere yet, so nothing tells that its rows are still to come.
      Without this boundary (the collector is not running, has not scanned the
      whole chain yet, or is configured with specific block ranges) nothing is
      processed.
    * the first block that does not have the coin balance of its miner
      (`Explorer.Chain.Address.CoinBalance.min_block_number_without_miner_coin_balance/2`).
      The collector counts a block as imported as soon as the block itself is
      stored, while its coin balances are written by a later stage of the same
      import, in another transaction, and the one of the block miner is always
      among them. A block without it is still being imported, or was left
      half-imported by an indexer that stopped between the two stages. The
      process waits at such a block and logs it once.
    * `head_offset` blocks below the chain head, as an extra distance from the
      blocks that are being imported.
    * the lowest block that has a transaction with a pending transaction
      operation (`Explorer.Chain.PendingTransactionOperation.min_block_number/0`).
      The internal transactions of such a transaction are not fetched yet, and
      `Explorer.Chain.Address.CoinBalance.delete_unchanged/3` leaves every row
      above that block in place. Going above it would skip those rows for good,
      so the process waits below it and logs it once. Finding that block takes
      a lookup per pending operation, so the pause before the next batch is
      never shorter than the batch itself took.

  The number of the last processed block is kept in `last_fetched_counters`, so
  the process continues from it after a restart. The rows that could not be
  deleted when their block was processed, because the blocks below them were not
  settled yet, are left in place.
  """

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  require Logger

  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.PendingTransactionOperation
  alias Indexer.Block.Catchup.MissingRangesCollector

  @counter_type "coin_balances_compactor_last_block_number"

  @interval :timer.seconds(1)
  @batch_size 100
  @head_offset 1000

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments}
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(init_opts, gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  @impl GenServer
  def init(_opts) do
    Kernel.send(self(), :compact)

    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:compact, state) do
    {duration, result} = :timer.tc(&compact_next_batch/0, :millisecond)

    # the pause is never shorter than the batch itself took, so that the process
    # backs off when a batch gets slow, e.g. with many pending transaction operations
    Process.send_after(self(), :compact, max(interval(), duration))

    {:noreply, log_waiting(result, state)}
  end

  # e.g. a late reply of the missing ranges collector to a call that timed out
  def handle_info(_message, state) do
    {:noreply, state}
  end

  # Logs the block the process is waiting at, once per block.
  defp log_waiting({reason, block_number} = waiting, state)
       when reason in [:waiting, :waiting_for_internal_transactions] do
    if Map.get(state, :waiting) != waiting do
      Logger.warning("Coin balances compactor is waiting at block #{block_number}: #{waiting_reason(reason)}")
    end

    Map.put(state, :waiting, waiting)
  end

  defp log_waiting(_result, state), do: Map.delete(state, :waiting)

  defp waiting_reason(:waiting) do
    "the coin balance of its miner is not there, so it is still being imported or was imported partially"
  end

  defp waiting_reason(:waiting_for_internal_transactions) do
    "a transaction of a block below it has a pending transaction operation, so its internal transactions are not fetched yet"
  end

  @doc """
  Processes the next batch of blocks, if there are settled blocks far enough
  from the chain head that are not processed yet.

  ## Returns
  - `{:ok, {from_block_number, to_block_number, deleted_count}}` for a processed batch.
  - `{:waiting, block_number}` when the next block to process does not have the coin balance of its miner yet.
  - `{:waiting_for_internal_transactions, block_number}` when a transaction of a block below the next block to
    process has a pending transaction operation.
  - `:idle` when there is nothing to process yet.
  """
  @spec compact_next_batch() ::
          {:ok, {non_neg_integer(), non_neg_integer(), non_neg_integer()}}
          | {:waiting, non_neg_integer()}
          | {:waiting_for_internal_transactions, non_neg_integer()}
          | :idle
  def compact_next_batch do
    from_block_number = last_block_number() + 1
    max_block_number = max_block_number()

    if not is_nil(max_block_number) and from_block_number <= max_block_number do
      compact_up_to(from_block_number, min(from_block_number + batch_size() - 1, max_block_number))
    else
      :idle
    end
  end

  # The pending transaction operations are looked at only when there are blocks to
  # process. A row is left in place by `CoinBalance.delete_unchanged/3` when a
  # block below it has such an operation, so the batch ends at the lowest of those
  # blocks, and nothing is processed while that block is below the batch.
  defp compact_up_to(from_block_number, to_block_number) do
    case PendingTransactionOperation.min_block_number() do
      pending_block_number when is_integer(pending_block_number) and pending_block_number < from_block_number ->
        {:waiting_for_internal_transactions, from_block_number}

      pending_block_number when is_integer(pending_block_number) ->
        compact_imported(from_block_number, min(to_block_number, pending_block_number))

      nil ->
        compact_imported(from_block_number, to_block_number)
    end
  end

  defp compact_imported(from_block_number, to_block_number) do
    case CoinBalance.min_block_number_without_miner_coin_balance(from_block_number, to_block_number) do
      nil -> compact(from_block_number, to_block_number)
      ^from_block_number -> {:waiting, from_block_number}
      block_number -> compact(from_block_number, block_number - 1)
    end
  end

  defp compact(from_block_number, to_block_number) do
    deleted_count = CoinBalance.delete_unchanged(from_block_number, to_block_number)

    {:ok, _} = LastFetchedCounter.upsert(%{counter_type: @counter_type, value: to_block_number})

    Logger.debug("Deleted #{deleted_count} unchanged coin balances in blocks #{from_block_number}..#{to_block_number}")

    {:ok, {from_block_number, to_block_number, deleted_count}}
  end

  # The highest block number that can be processed, or `nil` when it is not known
  # which blocks are settled.
  defp max_block_number do
    case MissingRangesCollector.settled_block_number() do
      nil -> nil
      settled_block_number -> min(settled_block_number, BlockNumber.get_max() - head_offset())
    end
  end

  # The block number the previous batch ended at, or -1 when nothing is processed yet.
  defp last_block_number do
    case LastFetchedCounter.get(@counter_type, nullable: true) do
      nil -> -1
      value -> Decimal.to_integer(value)
    end
  end

  defp batch_size do
    Application.get_env(:indexer, __MODULE__)[:batch_size] || @batch_size
  end

  defp interval do
    Application.get_env(:indexer, __MODULE__)[:interval] || @interval
  end

  defp head_offset do
    Application.get_env(:indexer, __MODULE__)[:head_offset] || @head_offset
  end
end
