# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.AddressCountersConsolidator do
  @moduledoc """
  The single writer of the per-address counters columns
  (`addresses.transactions_count`, `addresses.token_transfers_count`,
  `addresses.gas_used`).

  Periodically consolidates the counters of the addresses marked dirty in
  `Explorer.Chain.Cache.Counters.AddressCounters` (a cycle is skipped entirely
  when no address was marked since the last one):

  * an address with a `counters_updated_at` watermark gets three cheap
    range-bounded aggregates over `(counters_updated_at, safe_block]` whose
    results are added to the columns;
  * an address without a watermark (`NULL` — not yet backfilled, or reset by
    a deep reorg) gets full aggregates bounded by `safe_block` written as
    absolute values.

  `safe_block` stays a configurable lag behind the chain head so that shallow
  reorgs never invalidate consolidated ranges, and never advances past the
  lowest missing block range or block pending re-fetch counter correction, so
  that catchup and block re-fetch cannot make consolidated ranges lose or
  double-count rows.

  Each cycle starts by settling pending block re-fetch corrections: for every
  block whose old content was subtracted when it was queued for re-fetch (see
  `Explorer.Utility.AddressCountersRefetchBlock`) and which has been fully
  re-imported since, the new content is added back to the counters of the
  addresses whose watermark already covers the block.

  Known accepted limitations:

  * pending transactions are not counted (all aggregates are bounded by block
    number) — the legacy on-view counters included them;
  * `transactions_count`/`token_transfers_count` are clamped at the int4
    maximum of their columns;
  * a reorg deeper than the safety lag that lands while a consolidation cycle
    is aggregating the very same address can leave the forked content counted
    until the address is recalculated (watermark reset) for another reason.
  """

  use GenServer

  import Ecto.Query

  require Logger

  alias Explorer.Chain.{Address, Block, Hash, TokenTransfer, Transaction}
  alias Explorer.Chain.Address.Counters
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.{AddressCounters, Helper}
  alias Explorer.Repo
  alias Explorer.Utility.{AddressCountersRefetchBlock, MissingBlockRange}

  @int4_max 2_147_483_647
  @refetch_blocks_chunk_size 100

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    schedule_next_consolidation(:timer.seconds(10))

    {:ok, %{cycle_task: nil, cycle_started_at: nil, last_cycle_finished_at: nil}}
  end

  # A cycle can run for a long time (draining a large dirty backlog, full
  # recalculations of heavy addresses), so it runs in a separate supervised
  # task: the process itself stays responsive to system messages
  # (`:sys.get_state/1`, observer) and its state reports the running cycle.
  # The next cycle is scheduled only once the previous one finished, so cycles
  # never overlap.
  @impl true
  def handle_info(:consolidate, %{cycle_task: nil} = state) do
    task = Task.Supervisor.async_nolink(Explorer.TaskSupervisor, &consolidate/0)

    {:noreply, %{state | cycle_task: task, cycle_started_at: DateTime.utc_now()}}
  end

  # a stray tick while a cycle is still running — the next one is scheduled on
  # its completion
  def handle_info(:consolidate, state), do: {:noreply, state}

  def handle_info({ref, _result}, %{cycle_task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])

    {:noreply, finish_cycle(state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{cycle_task: %Task{ref: ref}} = state) do
    Logger.error(fn -> ["Address counters consolidation cycle crashed: ", inspect(reason)] end)

    {:noreply, finish_cycle(state)}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp finish_cycle(state) do
    schedule_next_consolidation(interval())

    %{state | cycle_task: nil, cycle_started_at: nil, last_cycle_finished_at: DateTime.utc_now()}
  end

  @doc """
  Runs one consolidation cycle synchronously. Exposed for tests and manual
  runs; the supervised process runs it in a task on every `:consolidate` tick.
  """
  @spec consolidate() :: :ok
  def consolidate do
    apply_pending_refetch_deltas()

    unless AddressCounters.dirty_empty?() do
      case safe_block() do
        nil -> :ok
        safe_block -> consolidate_dirty(AddressCounters.select_dirty(batch_size() * concurrency()), safe_block)
      end
    end

    :ok
  end

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
    case AddressCountersRefetchBlock.min_block_number() do
      block_number when is_integer(block_number) -> block_number - 1
      _ -> nil
    end
  end

  @doc """
  Consolidates the given addresses up to `safe_block` synchronously: full
  aggregates for addresses without a `counters_updated_at` watermark,
  incremental range aggregates for the rest. Used by
  `Explorer.Migrator.BackfillAddressCounters` and available for on-demand
  recalculation.
  """
  @spec consolidate_addresses([Hash.Address.t()], non_neg_integer()) :: :ok
  def consolidate_addresses(address_hashes, safe_block) do
    address_hashes
    |> Enum.map(& &1.bytes)
    |> load_addresses()
    |> Enum.reject(&(&1.counters_updated_at && &1.counters_updated_at >= safe_block))
    |> case do
      [] -> :ok
      addresses -> consolidate_chunk(addresses, safe_block)
    end

    :ok
  end

  defp consolidate_dirty(:"$end_of_table", _safe_block), do: :ok

  defp consolidate_dirty({entries, continuation}, safe_block) do
    process_entries(entries, safe_block)
    consolidate_dirty(AddressCounters.select_dirty(continuation), safe_block)
  end

  defp process_entries(entries, safe_block) do
    entry_bytes = Enum.map(entries, fn {bytes, _marker_block} -> bytes end)
    addresses_by_bytes = Map.new(load_addresses(entry_bytes), &{&1.hash.bytes, &1})

    {found_bytes, missing_bytes} = Enum.split_with(entry_bytes, &Map.has_key?(addresses_by_bytes, &1))

    # markers without a corresponding address row are garbage
    AddressCounters.delete_dirty_markers(missing_bytes, safe_block)

    found_bytes
    |> Enum.map(&Map.fetch!(addresses_by_bytes, &1))
    |> Enum.reject(&(&1.counters_updated_at && &1.counters_updated_at >= safe_block))
    |> Enum.chunk_every(batch_size())
    |> Task.async_stream(&consolidate_chunk(&1, safe_block), max_concurrency: concurrency(), timeout: :infinity)
    |> Stream.run()
  end

  defp consolidate_chunk(addresses, safe_block) do
    results =
      addresses
      |> Enum.map(&compute_address_deltas(&1, safe_block))
      |> Enum.reject(&is_nil/1)

    {increments, inits} = Enum.split_with(results, & &1.address.counters_updated_at)

    updated_rows = apply_increments(increments, safe_block) ++ apply_inits(inits, safe_block)
    updated_values_by_bytes = Map.new(updated_rows, &{&1.hash.bytes, &1})

    updated_results =
      Enum.filter(results, fn result -> Map.has_key?(updated_values_by_bytes, result.address.hash.bytes) end)

    Enum.each(updated_results, fn result ->
      bytes = result.address.hash.bytes
      new_values = Map.fetch!(updated_values_by_bytes, bytes)

      AddressCounters.refresh_from_consolidation(
        bytes,
        result.direction_field,
        %{
          transactions_count: new_values.transactions_count || 0,
          token_transfers_count: new_values.token_transfers_count || 0,
          gas_used: new_values.gas_used || 0
        },
        result.snapshot
      )
    end)

    updated_results
    |> Enum.map(& &1.address.hash.bytes)
    |> AddressCounters.delete_dirty_markers(safe_block)
  end

  defp compute_address_deltas(address, safe_block) do
    from_block_number = address.counters_updated_at
    direction_field = Counters.gas_usage_direction_field(address)
    snapshot = AddressCounters.snapshot(address.hash.bytes)

    transactions_count =
      address.hash
      |> Counters.address_hash_to_transaction_count_query(from_block_number, safe_block)
      |> Repo.aggregate(:count, :hash, timeout: query_timeout())

    token_transfers_count =
      address.hash
      |> Counters.address_to_token_transfer_count_query(from_block_number, safe_block)
      |> Repo.aggregate(:count, timeout: query_timeout())

    gas_used =
      address.hash
      |> Counters.address_to_gas_usage_sum_query(direction_field, from_block_number, safe_block)
      |> Repo.aggregate(:sum, :gas_used, timeout: query_timeout())
      |> Helper.gas_to_integer()

    %{
      address: address,
      direction_field: direction_field,
      snapshot: snapshot,
      transactions_count: transactions_count,
      token_transfers_count: token_transfers_count,
      gas_used: gas_used
    }
  rescue
    error ->
      Logger.warning(fn ->
        [
          "Failed to consolidate counters for address #{to_string(address.hash)}: ",
          Exception.format(:error, error, __STACKTRACE__)
        ]
      end)

      nil
  end

  defp apply_increments([], _safe_block), do: []

  defp apply_increments(results, safe_block) do
    hashes = Enum.map(results, & &1.address.hash.bytes)
    expected_froms = Enum.map(results, & &1.address.counters_updated_at)
    transactions_deltas = Enum.map(results, & &1.transactions_count)
    token_transfers_deltas = Enum.map(results, & &1.token_transfers_count)
    gas_deltas = Enum.map(results, & &1.gas_used)

    query =
      from(
        address in Address,
        join:
          deltas in fragment(
            """
            (SELECT unnest(?::bytea[]) AS hash, unnest(?::bigint[]) AS expected_from,
                    unnest(?::bigint[]) AS transactions_delta, unnest(?::bigint[]) AS token_transfers_delta,
                    unnest(?::bigint[]) AS gas_delta)
            """,
            ^hashes,
            ^expected_froms,
            ^transactions_deltas,
            ^token_transfers_deltas,
            ^gas_deltas
          ),
        on: address.hash == deltas.hash,
        where: address.hash in subquery(addresses_lock_query(hashes)),
        where: address.counters_updated_at == deltas.expected_from,
        update: [
          set: [
            transactions_count:
              fragment("LEAST(COALESCE(?, 0) + ?, ?)", address.transactions_count, deltas.transactions_delta, @int4_max),
            token_transfers_count:
              fragment(
                "LEAST(COALESCE(?, 0) + ?, ?)",
                address.token_transfers_count,
                deltas.token_transfers_delta,
                @int4_max
              ),
            gas_used: fragment("COALESCE(?, 0) + ?", address.gas_used, deltas.gas_delta),
            counters_updated_at: ^safe_block,
            updated_at: ^DateTime.utc_now()
          ]
        ],
        select: %{
          hash: address.hash,
          transactions_count: address.transactions_count,
          token_transfers_count: address.token_transfers_count,
          gas_used: address.gas_used
        }
      )

    {_count, rows} = Repo.update_all(query, [], timeout: query_timeout())

    rows
  end

  defp apply_inits([], _safe_block), do: []

  defp apply_inits(results, safe_block) do
    hashes = Enum.map(results, & &1.address.hash.bytes)
    transactions_counts = Enum.map(results, & &1.transactions_count)
    token_transfers_counts = Enum.map(results, & &1.token_transfers_count)
    gas_sums = Enum.map(results, & &1.gas_used)

    query =
      from(
        address in Address,
        join:
          values in fragment(
            """
            (SELECT unnest(?::bytea[]) AS hash, unnest(?::bigint[]) AS transactions_count,
                    unnest(?::bigint[]) AS token_transfers_count, unnest(?::bigint[]) AS gas_used)
            """,
            ^hashes,
            ^transactions_counts,
            ^token_transfers_counts,
            ^gas_sums
          ),
        on: address.hash == values.hash,
        where: address.hash in subquery(addresses_lock_query(hashes)),
        where: is_nil(address.counters_updated_at),
        update: [
          set: [
            transactions_count: fragment("LEAST(?, ?)", values.transactions_count, @int4_max),
            token_transfers_count: fragment("LEAST(?, ?)", values.token_transfers_count, @int4_max),
            gas_used: values.gas_used,
            counters_updated_at: ^safe_block,
            updated_at: ^DateTime.utc_now()
          ]
        ],
        select: %{
          hash: address.hash,
          transactions_count: address.transactions_count,
          token_transfers_count: address.token_transfers_count,
          gas_used: address.gas_used
        }
      )

    {_count, rows} = Repo.update_all(query, [], timeout: query_timeout())

    rows
  end

  defp load_addresses(hash_bytes_list) do
    hashes = Enum.map(hash_bytes_list, &%Hash{byte_count: 20, bytes: &1})

    query =
      from(address in Address,
        where: address.hash in ^hashes,
        select:
          struct(address, [
            :hash,
            :contract_code,
            :transactions_count,
            :token_transfers_count,
            :gas_used,
            :counters_updated_at
          ])
      )

    Repo.all(query, timeout: query_timeout())
  end

  ## Block re-fetch corrections (positive side)

  defp apply_pending_refetch_deltas do
    # a block is ready to settle once its re-fetch completed: the consensus
    # block no longer requires a re-fetch AND the block is no longer covered
    # by a missing range (the range row survives until the whole re-import —
    # all its stages — succeeded, so old content can no longer be observed)
    ready_query =
      from(refetch_block in AddressCountersRefetchBlock,
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

    case Repo.all(ready_query, timeout: query_timeout()) do
      [] ->
        :ok

      block_numbers ->
        settle_refetched_blocks(block_numbers)
        # more rows may be ready
        apply_pending_refetch_deltas()
    end
  rescue
    error ->
      Logger.error(fn ->
        ["Failed to settle re-fetched blocks counters: ", Exception.format(:error, error, __STACKTRACE__)]
      end)

      :ok
  end

  defp settle_refetched_blocks(block_numbers) do
    {:ok, updated_bytes} =
      Repo.transaction(
        fn ->
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
                select: struct(token_transfer, [:block_number, :from_address_hash, :to_address_hash])
              ),
              timeout: query_timeout()
            )

          updated_bytes = apply_covered_deltas(transactions, token_transfers, :positive)

          AddressCountersRefetchBlock.delete_by_block_numbers(Enum.sort(block_numbers))

          updated_bytes
        end,
        timeout: :infinity
      )

    AddressCounters.invalidate(updated_bytes)
  end

  @doc """
  Applies the per-address counter deltas of the given transactions and token
  transfers directly to the `addresses` columns, restricted per address to the
  blocks already covered by its `counters_updated_at` watermark (contributions
  above the watermark are left to regular range consolidation). `sign` selects
  whether the contributions are added (`:positive` — re-imported content of
  re-fetched blocks) or subtracted (`:negative` — old content of blocks queued
  for re-fetch, see `Explorer.Chain.Import.Runner.Blocks`).

  Runs on `Explorer.Repo` unless another repo is given. Returns the hash bytes
  of the updated addresses.
  """
  @spec apply_covered_deltas([map()], [map()], :positive | :negative, Ecto.Repo.t()) :: [binary()]
  def apply_covered_deltas(transactions, token_transfers, sign, repo \\ Repo) do
    watermarks =
      transactions
      |> participant_hashes(token_transfers)
      |> load_watermarks(repo)

    deltas =
      AddressCounters.compute_deltas(transactions, token_transfers, fn bytes, block_number ->
        case watermarks[bytes] do
          nil -> false
          watermark -> block_number <= watermark
        end
      end)

    if map_size(deltas) == 0 do
      []
    else
      apply_signed_deltas(deltas, watermarks, sign, repo)
    end
  end

  @doc """
  Resets the `counters_updated_at` watermark of the given addresses — forcing
  a full counters recalculation on their next consolidation — when their
  watermark already covers the given block number (a covered range changed
  under it: deep reorg, or rows inserted below the watermark by an
  out-of-band importer). Returns the hash bytes of the reset addresses; the
  caller is responsible for invalidating the display cache and marking them
  dirty.
  """
  @spec reset_covered_watermarks(%{binary() => non_neg_integer()}, Ecto.Repo.t()) :: [binary()]
  def reset_covered_watermarks(min_block_by_hash_bytes, repo \\ Repo)

  def reset_covered_watermarks(min_block_by_hash_bytes, _repo) when map_size(min_block_by_hash_bytes) == 0, do: []

  def reset_covered_watermarks(min_block_by_hash_bytes, repo) do
    {hashes, min_blocks} = min_block_by_hash_bytes |> Enum.sort() |> Enum.unzip()

    query =
      from(
        address in Address,
        join:
          affected in fragment(
            "(SELECT unnest(?::bytea[]) AS hash, unnest(?::bigint[]) AS block_number)",
            ^hashes,
            ^min_blocks
          ),
        on: address.hash == affected.hash,
        where: address.hash in subquery(addresses_lock_query(hashes)),
        where: not is_nil(address.counters_updated_at) and address.counters_updated_at >= affected.block_number,
        update: [set: [counters_updated_at: nil, updated_at: ^DateTime.utc_now()]],
        select: address.hash
      )

    {_count, reset_hashes} = repo.update_all(query, [], timeout: query_timeout())

    Enum.map(reset_hashes, & &1.bytes)
  end

  defp apply_signed_deltas(deltas, watermarks, sign, repo) do
    multiplier = if sign == :negative, do: -1, else: 1

    entries = Enum.to_list(deltas)
    hashes = Enum.map(entries, fn {bytes, _delta} -> bytes end)
    expected_watermarks = Enum.map(entries, fn {bytes, _delta} -> watermarks[bytes] end)
    transactions_deltas = Enum.map(entries, fn {_bytes, delta} -> multiplier * delta.transactions_count end)
    token_transfers_deltas = Enum.map(entries, fn {_bytes, delta} -> multiplier * delta.token_transfers_count end)
    gas_in_deltas = Enum.map(entries, fn {_bytes, delta} -> multiplier * delta.gas_in end)
    gas_out_deltas = Enum.map(entries, fn {_bytes, delta} -> multiplier * delta.gas_out end)

    query =
      from(
        address in Address,
        join:
          deltas in fragment(
            """
            (SELECT unnest(?::bytea[]) AS hash, unnest(?::bigint[]) AS expected_watermark,
                    unnest(?::bigint[]) AS transactions_delta, unnest(?::bigint[]) AS token_transfers_delta,
                    unnest(?::bigint[]) AS gas_in_delta, unnest(?::bigint[]) AS gas_out_delta)
            """,
            ^hashes,
            ^expected_watermarks,
            ^transactions_deltas,
            ^token_transfers_deltas,
            ^gas_in_deltas,
            ^gas_out_deltas
          ),
        on: address.hash == deltas.hash,
        where: address.hash in subquery(addresses_lock_query(hashes)),
        # only apply when the watermark is unchanged since the deltas were
        # computed; changed addresses are reset below for a full recalculation
        where: address.counters_updated_at == deltas.expected_watermark,
        update: [
          set: [
            transactions_count:
              fragment(
                "LEAST(GREATEST(COALESCE(?, 0) + ?, 0), ?)",
                address.transactions_count,
                deltas.transactions_delta,
                @int4_max
              ),
            token_transfers_count:
              fragment(
                "LEAST(GREATEST(COALESCE(?, 0) + ?, 0), ?)",
                address.token_transfers_count,
                deltas.token_transfers_delta,
                @int4_max
              ),
            # incoming gas for smart contracts, outgoing for EOAs — including
            # EIP-7702 EOAs with delegated code (code starts with 0xef0100)
            gas_used:
              fragment(
                """
                GREATEST(COALESCE(?, 0) + CASE
                  WHEN ? IS NULL OR substring(? from 1 for 3) = decode('ef0100', 'hex') THEN ?
                  ELSE ?
                END, 0)
                """,
                address.gas_used,
                address.contract_code,
                address.contract_code,
                deltas.gas_out_delta,
                deltas.gas_in_delta
              ),
            updated_at: ^DateTime.utc_now()
          ]
        ],
        select: address.hash
      )

    {_count, updated_hashes} = repo.update_all(query, [], timeout: query_timeout())

    updated_bytes = Enum.map(updated_hashes, & &1.bytes)

    # addresses whose watermark moved between the read and the guarded update
    # cannot be corrected by a delta anymore — force a full recalculation
    missed_reset_bytes =
      (hashes -- updated_bytes)
      |> Map.new(&{&1, 0})
      |> reset_covered_watermarks(repo)

    updated_bytes ++ missed_reset_bytes
  end

  defp participant_hashes(transactions, token_transfers) do
    (transactions ++ token_transfers)
    |> Enum.flat_map(fn row -> [row.from_address_hash, row.to_address_hash] end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&AddressCounters.hash_bytes/1)
    |> Enum.uniq()
  end

  defp load_watermarks(participant_bytes, repo) do
    hashes = Enum.map(participant_bytes, &%Hash{byte_count: 20, bytes: &1})

    from(address in Address,
      where: address.hash in ^hashes and not is_nil(address.counters_updated_at),
      select: {address.hash, address.counters_updated_at}
    )
    |> repo.all(timeout: query_timeout())
    |> Map.new(fn {hash, watermark} -> {hash.bytes, watermark} end)
  end

  # Enforce Address ShareLocks order (see docs: sharelocks.md)
  defp addresses_lock_query(hashes_bytes) do
    hashes = Enum.map(hashes_bytes, &%Hash{byte_count: 20, bytes: &1})

    from(
      address in Address,
      where: address.hash in ^hashes,
      select: address.hash,
      order_by: address.hash,
      lock: "FOR NO KEY UPDATE"
    )
  end

  defp schedule_next_consolidation(timeout) do
    Process.send_after(self(), :consolidate, timeout)
  end

  defp interval do
    Application.get_env(:explorer, __MODULE__)[:interval] || :timer.minutes(10)
  end

  defp batch_size do
    Application.get_env(:explorer, __MODULE__)[:batch_size] || 100
  end

  defp concurrency do
    Application.get_env(:explorer, __MODULE__)[:concurrency] || 4
  end

  defp safe_block_lag do
    Application.get_env(:explorer, __MODULE__)[:safe_block_lag] || 12
  end

  defp query_timeout do
    Application.get_env(:explorer, __MODULE__)[:query_timeout] || :timer.minutes(5)
  end
end
