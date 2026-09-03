# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.TokenCounters do
  @moduledoc """
  Shared ETS cache for the per-token transfers counter.

  The durable value lives in the `tokens.transfer_count` column and is
  advanced incrementally by
  `Explorer.Chain.Cache.Counters.TokenCountersConsolidator` up to the block
  number stored in `tokens.counters_updated_at`. The per-token holders counter
  (`tokens.holder_count`) is intentionally NOT cached here: it is maintained
  live by the import-time deltas of the current token balances runner, so the
  column itself is always current.

  This module keeps two ETS tables:

  * `:token_counters` — the display cache consumed by the API. Entries are
    seeded from the `transfer_count` column on read (`fetch/1`), incremented
    in place with the deltas of newly imported token transfers
    (`handle_new_data/2`), re-based from the DB by the consolidator
    (`refresh_from_consolidation/3`) and evicted a configurable TTL after
    their last authoritative base, so accumulated live-bump drift is bounded
    by the TTL. Live bumps never create entries.

  * `:token_counters_dirty` — the consolidator work list: token contract
    address hash bytes mapped to the maximum block number seen for the token
    since its last consolidation. Markers are written on nodes where the
    consolidator runs (`:indexer`/`:all` modes) and are capped at a
    configurable size — a dropped marker only delays consolidation until the
    token's next activity.

  On pure API nodes of split deployments the display cache is kept warm by the
  realtime `:token_transfers` chain events (dirty markers are not written
  there); on indexer and all-mode nodes `Explorer.Chain.Import` calls
  `handle_new_data/2` directly, so chain events are ignored there to avoid
  double counting.
  """

  use GenServer

  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.Helper
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.Hash

  @cache_name :token_counters
  @dirty_cache_name :token_counters_dirty

  @typedoc """
  Per-token contribution of a set of imported (or deleted) token transfers.
  """
  @type delta :: %{
          transfer_count: non_neg_integer(),
          max_block_number: non_neg_integer()
        }

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Helper.create_cache_table(@cache_name, write_concurrency: true)
    Helper.create_cache_table(@dirty_cache_name, write_concurrency: true)

    if Explorer.mode() == :api do
      Subscriber.to(:token_transfers, :realtime)
    end

    schedule_eviction()

    {:ok, %{}}
  end

  @doc """
  Returns the transfers counter for the given token: the cached value when
  present, the `tokens.transfer_count` column of the given struct otherwise
  (seeding the cache along the way). A token whose counter was never
  calculated (`NULL` column) is reported as zero and marked dirty so that the
  consolidator computes its value ahead of the background backfill (on nodes
  with a local consolidator).
  """
  @spec fetch(Explorer.Chain.Token.t()) :: non_neg_integer()
  def fetch(token) do
    if cache_table_exists?() do
      bytes = hash_bytes(token.contract_address_hash)

      case snapshot(bytes) do
        nil -> seed_from_db(token, bytes)
        transfer_count -> transfer_count
      end
    else
      token.transfer_count || 0
    end
  end

  @doc """
  Registers newly imported `token_transfers` in the cache: marks the involved
  tokens dirty for the consolidator and, when `live?` is `true` (realtime
  imports), increments the already-cached display values.
  """
  @spec handle_new_data([map()], boolean()) :: :ok
  def handle_new_data(token_transfers, live?) do
    if cache_table_exists?() do
      token_transfers
      |> compute_transfer_deltas()
      |> apply_new_deltas(live?)
    end

    :ok
  end

  defp apply_new_deltas(deltas, _live?) when map_size(deltas) == 0, do: :ok

  defp apply_new_deltas(deltas, live?) do
    if live? do
      Enum.each(deltas, fn {bytes, delta} -> bump_live(bytes, delta) end)
    end

    deltas
    |> Enum.map(fn {bytes, delta} -> {bytes, delta.max_block_number} end)
    |> mark_dirty()
  end

  @doc """
  Computes per-token transfer-count deltas for the given token transfers. Rows
  without a block number are skipped. The optional `include?` predicate
  receives the token contract hash bytes and the row block number and can
  exclude single contributions (used to restrict deltas to blocks at or below
  a token consolidation watermark).
  """
  @spec compute_transfer_deltas([map()], (binary(), non_neg_integer() -> boolean())) :: %{binary() => delta()}
  def compute_transfer_deltas(token_transfers, include? \\ fn _hash_bytes, _block_number -> true end) do
    Enum.reduce(token_transfers, %{}, &add_transfer_delta(&2, &1, include?))
  end

  defp add_transfer_delta(acc, token_transfer, include?) do
    bytes = hash_bytes(token_transfer.token_contract_address_hash)
    block_number = token_transfer.block_number

    if is_nil(bytes) or is_nil(block_number) or not include?.(bytes, block_number) do
      acc
    else
      acc
      |> Map.put_new(bytes, %{transfer_count: 0, max_block_number: 0})
      |> Map.update!(bytes, fn delta ->
        %{
          transfer_count: delta.transfer_count + 1,
          max_block_number: max(delta.max_block_number, block_number)
        }
      end)
    end
  end

  @doc """
  Increments the cached display value of the given token by the given delta.
  Only already-cached tokens are updated — live bumps never create entries.
  """
  @spec bump_live(binary(), delta()) :: :ok
  def bump_live(hash_bytes, delta) do
    if :ets.member(@cache_name, {hash_bytes, :transfer_count}) do
      :ets.update_counter(@cache_name, {hash_bytes, :transfer_count}, delta.transfer_count)
    end

    :ok
  rescue
    # the entry was evicted between the membership check and the update
    ArgumentError -> :ok
  end

  @doc """
  Returns the currently cached transfers counter of the given token or `nil`
  when the token is not cached.
  """
  @spec snapshot(binary()) :: non_neg_integer() | nil
  def snapshot(hash_bytes) do
    if cache_table_exists?() do
      Helper.fetch_from_ets_cache(@cache_name, {hash_bytes, :transfer_count})
    end
  end

  @doc """
  Re-bases the cached display value of the given token on the value just
  written to the DB by the consolidator. The write is an adjustment
  (`new value - snapshot`) rather than an overwrite, so live bumps applied
  concurrently — always for blocks above the consolidated range — survive on
  top of the new base.
  """
  @spec refresh_from_consolidation(binary(), non_neg_integer(), non_neg_integer() | nil) :: :ok
  def refresh_from_consolidation(hash_bytes, new_transfer_count, snapshot) do
    if not is_nil(snapshot) and :ets.member(@cache_name, {hash_bytes, :transfer_count}) do
      :ets.update_counter(@cache_name, {hash_bytes, :transfer_count}, new_transfer_count - snapshot)
      :ets.insert(@cache_name, {{hash_bytes, :ts}, Helper.current_time()})
    end

    :ok
  rescue
    # the entry was evicted between the membership check and the update
    ArgumentError -> :ok
  end

  @doc """
  Drops the cached display values of the given tokens so that the next read
  re-seeds them from the DB. Used after out-of-band DB counter corrections
  (block re-fetch deltas, watermark resets).
  """
  @spec invalidate([binary()]) :: :ok
  def invalidate(hash_bytes_list) do
    if cache_table_exists?() do
      Enum.each(hash_bytes_list, &delete_display_entries/1)
    end

    :ok
  end

  @doc """
  Marks tokens dirty for the consolidator. Accepts a list of
  `{hash_bytes, block_number}` pairs; for every token the maximum seen block
  number is kept. The update is serialized through the cache process to avoid
  losing the maximum on concurrent writes.

  A no-op on nodes without a local consolidator (pure API mode).
  """
  @spec mark_dirty([{binary(), non_neg_integer()}]) :: :ok
  def mark_dirty(pairs) when is_list(pairs) do
    if consolidator_local?() do
      GenServer.cast(__MODULE__, {:mark_dirty, pairs})
    end

    :ok
  end

  @doc """
  Marks the given token dirty at the current maximum block number, asking the
  consolidator to (re)calculate its counters from scratch when
  `counters_updated_at` is `NULL` or incrementally otherwise.
  """
  @spec mark_dirty_at_max_block(Hash.Address.t()) :: :ok
  def mark_dirty_at_max_block(contract_address_hash) do
    mark_dirty([{hash_bytes(contract_address_hash), BlockNumber.get_max()}])
  end

  @doc """
  Returns `true` when there are no dirty markers (or the cache is not started).
  """
  @spec dirty_empty?() :: boolean()
  def dirty_empty? do
    :ets.whereis(@dirty_cache_name) == :undefined or :ets.info(@dirty_cache_name, :size) == 0
  end

  @typedoc """
  Opaque `:ets.select/1` continuation of a dirty-markers traversal.
  """
  @type dirty_markers_continuation :: term()

  @doc """
  Starts (with a limit) or continues (with a previously returned continuation)
  a traversal of the dirty markers. Returns `{[{hash_bytes, block_number}], continuation}`
  or `:"$end_of_table"`.
  """
  @spec select_dirty(pos_integer() | dirty_markers_continuation()) ::
          {[{binary(), non_neg_integer()}], dirty_markers_continuation()} | :"$end_of_table"
  def select_dirty(limit) when is_integer(limit) do
    :ets.select(@dirty_cache_name, [{{:"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}], limit)
  end

  def select_dirty(continuation) do
    :ets.select(continuation)
  end

  @doc """
  Deletes the dirty markers of the given tokens unless a concurrent import
  bumped them above `safe_block` in the meantime (such markers stay for the
  next consolidation cycle).
  """
  @spec delete_dirty_markers([binary()], non_neg_integer()) :: :ok
  def delete_dirty_markers(hash_bytes_list, safe_block) do
    if :ets.whereis(@dirty_cache_name) != :undefined do
      Enum.each(hash_bytes_list, fn bytes ->
        :ets.select_delete(@dirty_cache_name, [{{bytes, :"$1"}, [{:"=<", :"$1", safe_block}], [true]}])
      end)
    end

    :ok
  end

  @doc """
  Converts a token contract address hash (or already-extracted hash bytes) to
  the binary key used in the cache tables.
  """
  @spec hash_bytes(Hash.Address.t() | binary() | nil) :: binary() | nil
  def hash_bytes(nil), do: nil
  def hash_bytes(%Hash{bytes: bytes}), do: bytes
  def hash_bytes(bytes) when is_binary(bytes), do: bytes

  def cache_name, do: @cache_name
  def dirty_cache_name, do: @dirty_cache_name

  @impl true
  def handle_cast({:mark_dirty, pairs}, state) do
    Enum.each(pairs, fn {bytes, block_number} -> insert_dirty_marker(bytes, block_number) end)

    {:noreply, state}
  end

  defp insert_dirty_marker(bytes, block_number) do
    case :ets.lookup(@dirty_cache_name, bytes) do
      [{_, existing}] when existing >= block_number ->
        :ok

      [{_, _existing}] ->
        :ets.insert(@dirty_cache_name, {bytes, block_number})

      [] ->
        # cap the work list: a dropped marker only delays consolidation until
        # the token's next activity (during initial sync all tokens are
        # covered by the backfill migration anyway)
        if :ets.info(@dirty_cache_name, :size) < max_dirty_markers() do
          :ets.insert(@dirty_cache_name, {bytes, block_number})
        end
    end
  end

  @impl true
  def handle_info({:chain_event, :token_transfers, :realtime, token_transfers}, state) do
    handle_new_data(token_transfers, true)
    {:noreply, state}
  end

  def handle_info(:evict, state) do
    evict_stale_entries()
    schedule_eviction()
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp seed_from_db(token, bytes) do
    if is_nil(token.transfer_count) do
      mark_dirty([{bytes, BlockNumber.get_max()}])

      0
    else
      :ets.insert_new(@cache_name, [
        {{bytes, :transfer_count}, token.transfer_count},
        {{bytes, :ts}, Helper.current_time()}
      ])

      token.transfer_count
    end
  end

  defp delete_display_entries(bytes) do
    Enum.each([:transfer_count, :ts], fn key ->
      :ets.delete(@cache_name, {bytes, key})
    end)
  end

  defp evict_stale_entries do
    threshold = Helper.current_time() - ttl()

    @cache_name
    |> :ets.select([{{{:"$1", :ts}, :"$2"}, [{:<, :"$2", threshold}], [:"$1"]}])
    |> Enum.each(&delete_display_entries/1)
  end

  defp cache_table_exists? do
    :ets.whereis(@cache_name) != :undefined
  end

  defp consolidator_local? do
    Explorer.mode() in [:indexer, :all]
  end

  defp max_dirty_markers do
    Application.get_env(:explorer, __MODULE__)[:max_dirty_markers] || 200_000
  end

  defp schedule_eviction do
    Process.send_after(self(), :evict, max(div(ttl(), 4), :timer.minutes(1)))
  end

  defp ttl do
    Application.get_env(:explorer, __MODULE__)[:ttl] || :timer.hours(2)
  end
end
