# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.TokenCountersConsolidator do
  @moduledoc """
  The single writer of the per-token counters columns (`tokens.transfer_count`
  and — on the initialization path only — `tokens.holder_count`).

  Periodically consolidates the counters of the tokens marked dirty in
  `Explorer.Chain.Cache.Counters.TokenCounters` (a cycle is skipped entirely
  when no token was marked since the last one):

  * a token with a `counters_updated_at` watermark gets a cheap range-bounded
    `COUNT(*)` of its token transfers over `(counters_updated_at, safe_block]`
    added to `transfer_count`;
  * a token without a watermark (`NULL` — not yet backfilled, or reset because
    covered content changed) gets a full transfer count bounded by
    `safe_block`, and its `holder_count` re-established from a full recount.

  `holder_count` is otherwise maintained live by the import-time deltas of the
  current token balances runner (state count — it cannot be recomputed from a
  block range), so the recount here is written as a snapshot-relative
  adjustment: the token is first "armed" (`holder_count` set to `0` when
  `NULL`, enabling the delta guard), then the current count and the pre-count
  column value are measured in one statement (one snapshot), and finally
  `holder_count = holder_count - measured_old + recount` is applied — deltas
  committed between the measurement and the guarded update survive on top of
  the recount (READ COMMITTED re-reads the locked row, while the measured
  values keep the measurement snapshot).

  `safe_block` (shared with the address counters consolidation — see
  `Explorer.Chain.Cache.Counters.Consolidation`) keeps watermarks a
  configurable lag behind the chain head and never advances past missing block
  ranges or blocks pending re-fetch corrections. Token transfers of forked
  blocks keep their physical rows (only `block_consensus` flips), and the
  counter counts physical rows — legacy parity — so forks need no token
  watermark resets; re-imported rows landing below a watermark are handled by
  the reset valve in `Explorer.Chain.Import`.

  Known accepted limitations mirror the address consolidator: int4 clamping,
  and content changes below a watermark landing while the very same token is
  being consolidated can leave stale counts until the next watermark reset.
  A one-off migrator deleting token transfer rows invalidates consolidated
  transfer counts — reset `tokens.counters_updated_at` to `NULL` afterwards.
  """

  use GenServer

  import Ecto.Query
  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  require Logger

  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.{Consolidation, TokenCounters}
  alias Explorer.Chain.{Hash, Token, TokenTransfer}
  alias Explorer.Repo

  @int4_max 2_147_483_647

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
  # recalculations of heavy tokens), so it runs in a separate supervised task:
  # the process itself stays responsive to system messages (`:sys.get_state/1`,
  # observer) and its state reports the running cycle. The next cycle is
  # scheduled only once the previous one finished, so cycles never overlap.
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
    Logger.error(fn -> ["Token counters consolidation cycle crashed: ", inspect(reason)] end)

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
    Consolidation.settle_pending_refetch_blocks()

    unless TokenCounters.dirty_empty?() do
      case Consolidation.safe_block() do
        nil -> :ok
        safe_block -> consolidate_dirty(TokenCounters.select_dirty(batch_size() * concurrency()), safe_block)
      end
    end

    :ok
  end

  @doc """
  Consolidates the given tokens up to `safe_block` synchronously: full
  recalculation (transfer count and holder recount) for tokens without a
  `counters_updated_at` watermark, incremental transfer-count range aggregates
  for the rest. Used by `Explorer.Migrator.BackfillTokenCounters` and
  available for on-demand recalculation.
  """
  @spec consolidate_tokens([Hash.Address.t()], non_neg_integer()) :: :ok
  def consolidate_tokens(contract_address_hashes, safe_block) do
    contract_address_hashes
    |> Enum.map(& &1.bytes)
    |> load_tokens()
    |> Enum.reject(&(&1.counters_updated_at && &1.counters_updated_at >= safe_block))
    |> case do
      [] -> :ok
      tokens -> consolidate_chunk(tokens, safe_block)
    end

    :ok
  end

  defp consolidate_dirty(:"$end_of_table", _safe_block), do: :ok

  defp consolidate_dirty({entries, continuation}, safe_block) do
    process_entries(entries, safe_block)
    consolidate_dirty(TokenCounters.select_dirty(continuation), safe_block)
  end

  defp process_entries(entries, safe_block) do
    entry_bytes = Enum.map(entries, fn {bytes, _marker_block} -> bytes end)
    tokens_by_bytes = Map.new(load_tokens(entry_bytes), &{&1.contract_address_hash.bytes, &1})

    {found_bytes, missing_bytes} = Enum.split_with(entry_bytes, &Map.has_key?(tokens_by_bytes, &1))

    # markers without a corresponding token row are garbage
    TokenCounters.delete_dirty_markers(missing_bytes, safe_block)

    found_bytes
    |> Enum.map(&Map.fetch!(tokens_by_bytes, &1))
    |> Enum.reject(&(&1.counters_updated_at && &1.counters_updated_at >= safe_block))
    |> Enum.chunk_every(batch_size())
    |> Task.async_stream(&consolidate_chunk(&1, safe_block), max_concurrency: concurrency(), timeout: :infinity)
    |> Stream.run()
  end

  defp consolidate_chunk(tokens, safe_block) do
    {incremental_tokens, inits} = Enum.split_with(tokens, & &1.counters_updated_at)

    updated_rows =
      consolidate_incremental_tokens(incremental_tokens, safe_block) ++ consolidate_inits(inits, safe_block)

    Enum.each(updated_rows, fn %{token: token, transfer_count: new_transfer_count, snapshot: snapshot} ->
      TokenCounters.refresh_from_consolidation(token.contract_address_hash.bytes, new_transfer_count || 0, snapshot)
    end)

    updated_rows
    |> Enum.map(& &1.token.contract_address_hash.bytes)
    |> TokenCounters.delete_dirty_markers(safe_block)
  end

  ## Incremental path

  defp consolidate_incremental_tokens([], _safe_block), do: []

  defp consolidate_incremental_tokens(tokens, safe_block) do
    results =
      tokens
      |> Enum.map(&compute_transfer_range_count(&1, safe_block))
      |> Enum.reject(&is_nil/1)

    apply_increments(results, safe_block)
  end

  defp compute_transfer_range_count(token, safe_block) do
    snapshot = TokenCounters.snapshot(token.contract_address_hash.bytes)

    transfer_count_delta =
      token.contract_address_hash
      |> TokenTransfer.count_token_transfers_from_token_hash_query(token.counters_updated_at, safe_block)
      |> Repo.aggregate(:count, timeout: query_timeout())

    %{token: token, snapshot: snapshot, transfer_count_delta: transfer_count_delta}
  rescue
    error ->
      Logger.warning(fn ->
        [
          "Failed to consolidate counters for token #{to_string(token.contract_address_hash)}: ",
          Exception.format(:error, error, __STACKTRACE__)
        ]
      end)

      nil
  end

  defp apply_increments([], _safe_block), do: []

  defp apply_increments(results, safe_block) do
    hashes = Enum.map(results, & &1.token.contract_address_hash.bytes)
    expected_froms = Enum.map(results, & &1.token.counters_updated_at)
    transfer_deltas = Enum.map(results, & &1.transfer_count_delta)

    query =
      from(
        token in Token,
        join:
          deltas in fragment(
            "(SELECT unnest(?::bytea[]) AS hash, unnest(?::bigint[]) AS expected_from, unnest(?::bigint[]) AS transfer_delta)",
            ^hashes,
            ^expected_froms,
            ^transfer_deltas
          ),
        on: token.contract_address_hash == deltas.hash,
        where: token.contract_address_hash in subquery(tokens_lock_query(hashes)),
        where: token.counters_updated_at == deltas.expected_from,
        update: [
          set: [
            transfer_count:
              fragment("LEAST(COALESCE(?, 0) + ?, ?)", token.transfer_count, deltas.transfer_delta, @int4_max),
            counters_updated_at: ^safe_block,
            updated_at: ^DateTime.utc_now()
          ]
        ],
        select: %{hash: token.contract_address_hash, transfer_count: token.transfer_count}
      )

    {_count, rows} = Repo.update_all(query, [], timeout: query_timeout())

    rows_by_bytes = Map.new(rows, &{&1.hash.bytes, &1})

    results
    |> Enum.filter(&Map.has_key?(rows_by_bytes, &1.token.contract_address_hash.bytes))
    |> Enum.map(fn result ->
      %{
        token: result.token,
        snapshot: result.snapshot,
        transfer_count: Map.fetch!(rows_by_bytes, result.token.contract_address_hash.bytes).transfer_count
      }
    end)
  end

  ## Initialization path (NULL watermark): arm -> measure -> apply

  defp consolidate_inits([], _safe_block), do: []

  defp consolidate_inits(tokens, safe_block) do
    hashes = Enum.map(tokens, & &1.contract_address_hash.bytes)

    arm_holder_counts(hashes)

    results =
      tokens
      |> Enum.map(&measure_token(&1, safe_block))
      |> Enum.reject(&is_nil/1)

    apply_inits(results, safe_block)
  end

  # Sets `holder_count` to 0 where it is NULL so that the import-time delta
  # machinery (guarded by `not is_nil(holder_count)`) accumulates every
  # transition committed after this point; the measured recount then lands as
  # an adjustment on top (see the moduledoc).
  defp arm_holder_counts(hashes) do
    query =
      from(token in Token,
        where: token.contract_address_hash in subquery(tokens_lock_query(hashes)),
        where: is_nil(token.holder_count),
        update: [set: [holder_count: 0, updated_at: ^DateTime.utc_now()]]
      )

    Repo.update_all(query, [], timeout: query_timeout())
  end

  defp measure_token(token, safe_block) do
    # one statement = one snapshot: the pre-recount column value and the
    # recount are consistent with each other
    {old_holder_count, holder_recount} =
      Repo.one!(
        from(t in Token,
          where: t.contract_address_hash == ^token.contract_address_hash,
          select: {
            coalesce(t.holder_count, 0),
            fragment(
              """
              (SELECT COUNT(DISTINCT ctb.address_hash)
                 FROM address_current_token_balances ctb
                WHERE ctb.token_contract_address_hash = ?
                  AND ctb.address_hash <> ?
                  AND (ctb.value > 0 OR ctb.token_type = 'ERC-7984'))
              """,
              t.contract_address_hash,
              ^burn_address_bytes()
            )
          }
        ),
        timeout: query_timeout()
      )

    transfer_count =
      token.contract_address_hash
      |> TokenTransfer.count_token_transfers_from_token_hash_query(nil, safe_block)
      |> Repo.aggregate(:count, timeout: query_timeout())

    snapshot = TokenCounters.snapshot(token.contract_address_hash.bytes)

    %{
      token: token,
      snapshot: snapshot,
      old_holder_count: old_holder_count,
      holder_recount: holder_recount,
      transfer_count: transfer_count
    }
  rescue
    error ->
      Logger.warning(fn ->
        [
          "Failed to recalculate counters for token #{to_string(token.contract_address_hash)}: ",
          Exception.format(:error, error, __STACKTRACE__)
        ]
      end)

      nil
  end

  defp apply_inits([], _safe_block), do: []

  defp apply_inits(results, safe_block) do
    hashes = Enum.map(results, & &1.token.contract_address_hash.bytes)
    old_holder_counts = Enum.map(results, & &1.old_holder_count)
    holder_recounts = Enum.map(results, & &1.holder_recount)
    transfer_counts = Enum.map(results, & &1.transfer_count)

    query =
      from(
        token in Token,
        join:
          values in fragment(
            """
            (SELECT unnest(?::bytea[]) AS hash, unnest(?::bigint[]) AS old_holder_count,
                    unnest(?::bigint[]) AS holder_recount, unnest(?::bigint[]) AS transfer_count)
            """,
            ^hashes,
            ^old_holder_counts,
            ^holder_recounts,
            ^transfer_counts
          ),
        on: token.contract_address_hash == values.hash,
        where: token.contract_address_hash in subquery(tokens_lock_query(hashes)),
        where: is_nil(token.counters_updated_at),
        update: [
          set: [
            # snapshot-relative: deltas committed since the measurement stay
            holder_count:
              fragment(
                "LEAST(GREATEST(COALESCE(?, 0) - ? + ?, 0), ?)",
                token.holder_count,
                values.old_holder_count,
                values.holder_recount,
                @int4_max
              ),
            transfer_count: fragment("LEAST(?, ?)", values.transfer_count, @int4_max),
            counters_updated_at: ^safe_block,
            updated_at: ^DateTime.utc_now()
          ]
        ],
        select: %{hash: token.contract_address_hash, transfer_count: token.transfer_count}
      )

    {_count, rows} = Repo.update_all(query, [], timeout: query_timeout())

    rows_by_bytes = Map.new(rows, &{&1.hash.bytes, &1})

    results
    |> Enum.filter(&Map.has_key?(rows_by_bytes, &1.token.contract_address_hash.bytes))
    |> Enum.map(fn result ->
      %{
        token: result.token,
        snapshot: result.snapshot,
        transfer_count: Map.fetch!(rows_by_bytes, result.token.contract_address_hash.bytes).transfer_count
      }
    end)
  end

  ## Covered deltas (block re-fetch corrections)

  @doc """
  Applies the per-token transfer-count deltas of the given token transfers
  directly to `tokens.transfer_count`, restricted per token to the blocks
  already covered by its `counters_updated_at` watermark (contributions above
  the watermark are left to regular range consolidation). `sign` selects
  whether the contributions are added (`:positive` — re-imported content of
  re-fetched blocks) or subtracted (`:negative` — old content of blocks queued
  for re-fetch, see `Explorer.Chain.Import.Runner.Blocks`).

  Runs on `Explorer.Repo` unless another repo is given. Returns the hash bytes
  of the updated tokens.
  """
  @spec apply_covered_transfer_deltas([map()], :positive | :negative, Ecto.Repo.t()) :: [binary()]
  def apply_covered_transfer_deltas(token_transfers, sign, repo \\ Repo) do
    watermarks =
      token_transfers
      |> Enum.map(&TokenCounters.hash_bytes(&1.token_contract_address_hash))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> load_watermarks(repo)

    deltas =
      TokenCounters.compute_transfer_deltas(token_transfers, fn bytes, block_number ->
        case watermarks[bytes] do
          nil -> false
          watermark -> block_number <= watermark
        end
      end)

    if map_size(deltas) == 0 do
      []
    else
      apply_signed_transfer_deltas(deltas, watermarks, sign, repo)
    end
  end

  @doc """
  Resets the `counters_updated_at` watermark of the given tokens — forcing a
  full counters recalculation on their next consolidation — when their
  watermark already covers the given block number (a covered range changed
  under it: rows inserted below the watermark, or a missed correction guard).
  Reset tokens are marked dirty so the recalculation is actually scheduled.
  Returns the hash bytes of the reset tokens; the caller is responsible for
  invalidating the display cache.
  """
  @spec reset_covered_watermarks(%{binary() => non_neg_integer()}, Ecto.Repo.t()) :: [binary()]
  def reset_covered_watermarks(min_block_by_hash_bytes, repo \\ Repo)

  def reset_covered_watermarks(min_block_by_hash_bytes, _repo) when map_size(min_block_by_hash_bytes) == 0, do: []

  def reset_covered_watermarks(min_block_by_hash_bytes, repo) do
    {hashes, min_blocks} = min_block_by_hash_bytes |> Enum.sort() |> Enum.unzip()

    query =
      from(
        token in Token,
        join:
          affected in fragment(
            "(SELECT unnest(?::bytea[]) AS hash, unnest(?::bigint[]) AS block_number)",
            ^hashes,
            ^min_blocks
          ),
        on: token.contract_address_hash == affected.hash,
        where: token.contract_address_hash in subquery(tokens_lock_query(hashes)),
        where: not is_nil(token.counters_updated_at) and token.counters_updated_at >= affected.block_number,
        update: [set: [counters_updated_at: nil, updated_at: ^DateTime.utc_now()]],
        select: token.contract_address_hash
      )

    {_count, reset_hashes} = repo.update_all(query, [], timeout: query_timeout())

    reset_bytes = Enum.map(reset_hashes, & &1.bytes)

    # a spurious marker on transaction rollback is harmless (the guarded
    # consolidation of a non-reset token is a no-op)
    TokenCounters.mark_dirty(Enum.map(reset_bytes, &{&1, BlockNumber.get_max()}))

    reset_bytes
  end

  defp apply_signed_transfer_deltas(deltas, watermarks, sign, repo) do
    multiplier = if sign == :negative, do: -1, else: 1

    entries = Enum.to_list(deltas)
    hashes = Enum.map(entries, fn {bytes, _delta} -> bytes end)
    expected_watermarks = Enum.map(entries, fn {bytes, _delta} -> watermarks[bytes] end)
    transfer_deltas = Enum.map(entries, fn {_bytes, delta} -> multiplier * delta.transfer_count end)

    query =
      from(
        token in Token,
        join:
          deltas in fragment(
            "(SELECT unnest(?::bytea[]) AS hash, unnest(?::bigint[]) AS expected_watermark, unnest(?::bigint[]) AS transfer_delta)",
            ^hashes,
            ^expected_watermarks,
            ^transfer_deltas
          ),
        on: token.contract_address_hash == deltas.hash,
        where: token.contract_address_hash in subquery(tokens_lock_query(hashes)),
        # only apply when the watermark is unchanged since the deltas were
        # computed; changed tokens are reset below for a full recalculation
        where: token.counters_updated_at == deltas.expected_watermark,
        update: [
          set: [
            transfer_count:
              fragment(
                "LEAST(GREATEST(COALESCE(?, 0) + ?, 0), ?)",
                token.transfer_count,
                deltas.transfer_delta,
                @int4_max
              ),
            updated_at: ^DateTime.utc_now()
          ]
        ],
        select: token.contract_address_hash
      )

    {_count, updated_hashes} = repo.update_all(query, [], timeout: query_timeout())

    updated_bytes = Enum.map(updated_hashes, & &1.bytes)

    # tokens whose watermark moved between the read and the guarded update
    # cannot be corrected by a delta anymore — force a full recalculation
    missed_reset_bytes =
      (hashes -- updated_bytes)
      |> Map.new(&{&1, 0})
      |> reset_covered_watermarks(repo)

    updated_bytes ++ missed_reset_bytes
  end

  defp load_watermarks(token_bytes_list, repo) do
    hashes = Enum.map(token_bytes_list, &%Hash{byte_count: 20, bytes: &1})

    from(token in Token,
      where: token.contract_address_hash in ^hashes and not is_nil(token.counters_updated_at),
      select: {token.contract_address_hash, token.counters_updated_at}
    )
    |> repo.all(timeout: query_timeout())
    |> Map.new(fn {hash, watermark} -> {hash.bytes, watermark} end)
  end

  defp load_tokens(hash_bytes_list) do
    hashes = Enum.map(hash_bytes_list, &%Hash{byte_count: 20, bytes: &1})

    query =
      from(token in Token,
        where: token.contract_address_hash in ^hashes,
        select: struct(token, [:contract_address_hash, :holder_count, :transfer_count, :counters_updated_at])
      )

    Repo.all(query, timeout: query_timeout())
  end

  # Enforce Token ShareLocks order (see docs: sharelocks.md)
  defp tokens_lock_query(hashes_bytes) do
    hashes = Enum.map(hashes_bytes, &%Hash{byte_count: 20, bytes: &1})

    from(
      token in Token,
      where: token.contract_address_hash in ^hashes,
      select: token.contract_address_hash,
      order_by: token.contract_address_hash,
      lock: "FOR NO KEY UPDATE"
    )
  end

  defp burn_address_bytes do
    {:ok, burn_address_hash} = Hash.Address.cast(burn_address_hash_string())

    burn_address_hash.bytes
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
    Application.get_env(:explorer, __MODULE__)[:concurrency] || 2
  end

  defp query_timeout do
    Application.get_env(:explorer, __MODULE__)[:query_timeout] || :timer.minutes(5)
  end
end
