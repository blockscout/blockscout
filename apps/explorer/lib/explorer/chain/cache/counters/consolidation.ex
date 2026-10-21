# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.Consolidation do
  @moduledoc """
  Plumbing shared by the incremental counter consolidators
  (`Explorer.Chain.Cache.Counters.AddressCountersConsolidator` and
  `Explorer.Chain.Cache.Counters.TokenCountersConsolidator`):

  * `safe_block/0` — the highest block number consolidated ranges may cover;
  * `settle_pending_refetch_blocks/0` — applies the pending positive counter
    corrections for re-fetched blocks (see `Explorer.Utility.CountersRefetchBlock`)
    to both the address and the token counters.

  Both consolidators call the settle at the start of their cycles; a
  transaction-scoped advisory lock guarantees the corrections are applied
  exactly once even when the cycles overlap.
  """

  import Ecto.Query

  require Logger

  alias Explorer.Chain.{Block, TokenTransfer, Transaction}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.{AddressCounters, AddressCountersConsolidator, TokenCounters}
  alias Explorer.Chain.Cache.Counters.TokenCountersConsolidator
  alias Explorer.Repo
  alias Explorer.Utility.{CountersRefetchBlock, MissingBlockRange}

  @refetch_blocks_chunk_size 100

  # arbitrary constant identifying the settle critical section among
  # `pg_advisory_xact_lock` users
  @settle_advisory_lock_key 7_235_622_386_001

  @doc """
  Returns the highest block number consolidated ranges may currently cover or
  `nil` when consolidation is not possible yet: the chain head minus the
  configured safety lag, additionally capped below the lowest missing block
  range and the lowest block pending a re-fetch counter correction.

  While the chain is not yet indexed down to the configured first block —
  initial backward sync, before the missing ranges collector has recorded the
  unindexed tail — no safe block exists at all: consolidating past blocks that
  are absent but not yet registered in `missing_block_ranges` would lose their
  contributions forever.
  """
  @spec safe_block() :: non_neg_integer() | nil
  def safe_block do
    if lower_chain_indexed?() do
      [lagged_head(), min_missing_block_cap(), min_pending_refetch_cap()]
      |> Enum.reject(&is_nil/1)
      |> Enum.min(fn -> nil end)
      |> case do
        safe_block when is_integer(safe_block) and safe_block > 0 -> safe_block
        _ -> nil
      end
    end
  end

  @doc """
  Returns the configured number of blocks the consolidation watermarks stay
  behind the chain head.
  """
  @spec safe_block_lag() :: non_neg_integer()
  def safe_block_lag do
    Application.get_env(:explorer, __MODULE__)[:safe_block_lag] || 12
  end

  @doc """
  Settles the pending block re-fetch corrections: for every queued block whose
  re-fetch fully completed, adds the counter contributions of the re-imported
  content back to the addresses and tokens whose watermarks already cover the
  block, then drops the queue rows. Blocks whose re-import is still in flight
  (the consensus block still requires a re-fetch, or the block is still
  covered by a missing range) are left queued.
  """
  @spec settle_pending_refetch_blocks() :: :ok
  def settle_pending_refetch_blocks do
    case Repo.all(ready_to_settle_query(), timeout: query_timeout()) do
      [] ->
        :ok

      block_numbers ->
        case settle_refetched_blocks(block_numbers) do
          # another settle is in progress on this or another node
          :skipped -> :ok
          # more rows may be ready
          :ok -> settle_pending_refetch_blocks()
        end
    end
  rescue
    error ->
      Logger.error(fn ->
        ["Failed to settle re-fetched blocks counters: ", Exception.format(:error, error, __STACKTRACE__)]
      end)

      :ok
  end

  # a block is ready to settle once its re-fetch completed: the consensus
  # block no longer requires a re-fetch AND the block is no longer covered
  # by a missing range (the range row survives until the whole re-import —
  # all its stages — succeeded, so old content can no longer be observed)
  defp ready_to_settle_query do
    from(refetch_block in CountersRefetchBlock,
      as: :refetch_block,
      where:
        not exists(
          from(block in Block,
            where:
              block.number == parent_as(:refetch_block).block_number and block.consensus == true and
                block.refetch_needed == true,
            select: 1
          )
        ),
      where:
        not exists(
          from(range in MissingBlockRange,
            where:
              range.from_number >= parent_as(:refetch_block).block_number and
                range.to_number <= parent_as(:refetch_block).block_number,
            select: 1
          )
        ),
      select: refetch_block.block_number,
      limit: @refetch_blocks_chunk_size
    )
  end

  defp settle_refetched_blocks(block_numbers) do
    {:ok, result} =
      Repo.transaction(
        fn ->
          if advisory_lock_acquired?() do
            transactions =
              Repo.all(
                from(transaction in Transaction,
                  where: transaction.block_number in ^block_numbers,
                  select: struct(transaction, [:block_number, :from_address_hash, :to_address_hash, :gas_used])
                ),
                timeout: query_timeout()
              )

            token_transfers =
              Repo.all(
                from(token_transfer in TokenTransfer,
                  where: token_transfer.block_number in ^block_numbers,
                  select:
                    struct(token_transfer, [
                      :block_number,
                      :from_address_hash,
                      :to_address_hash,
                      :token_contract_address_hash
                    ])
                ),
                timeout: query_timeout()
              )

            updated_address_bytes =
              AddressCountersConsolidator.apply_covered_deltas(transactions, token_transfers, :positive)

            updated_token_bytes = TokenCountersConsolidator.apply_covered_transfer_deltas(token_transfers, :positive)

            CountersRefetchBlock.delete_by_block_numbers(Enum.sort(block_numbers))

            {updated_address_bytes, updated_token_bytes}
          else
            :skipped
          end
        end,
        timeout: :infinity
      )

    case result do
      :skipped ->
        :skipped

      {updated_address_bytes, updated_token_bytes} ->
        AddressCounters.invalidate(updated_address_bytes)
        TokenCounters.invalidate(updated_token_bytes)
        :ok
    end
  end

  defp advisory_lock_acquired? do
    %{rows: [[acquired]]} = Repo.query!("SELECT pg_try_advisory_xact_lock($1)", [@settle_advisory_lock_key])

    acquired
  end

  defp lower_chain_indexed? do
    first_block = Application.get_env(:indexer, :first_block)

    case BlockNumber.get_min() do
      min_block_number when is_integer(min_block_number) -> min_block_number <= first_block
      _ -> false
    end
  end

  defp lagged_head do
    case BlockNumber.get_max() do
      max_block_number when is_integer(max_block_number) -> max_block_number - safe_block_lag()
      _ -> nil
    end
  end

  defp min_missing_block_cap do
    case MissingBlockRange.fetch_min_max() do
      %{min: min} when is_integer(min) -> min - 1
      _ -> nil
    end
  end

  defp min_pending_refetch_cap do
    case CountersRefetchBlock.min_block_number() do
      block_number when is_integer(block_number) -> block_number - 1
      _ -> nil
    end
  end

  defp query_timeout do
    Application.get_env(:explorer, __MODULE__)[:query_timeout] || :timer.minutes(5)
  end
end
