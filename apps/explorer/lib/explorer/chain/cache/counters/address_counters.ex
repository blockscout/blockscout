# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.AddressCounters do
  @moduledoc """
  Shared ETS cache for the per-address counters: transactions count, token
  transfers count and gas usage sum.

  The durable values live in the `addresses` table columns
  (`transactions_count`, `token_transfers_count`, `gas_used`) and are advanced
  incrementally by `Explorer.Chain.Cache.Counters.AddressCountersConsolidator`
  up to the block number stored in `addresses.counters_updated_at`. This
  module keeps two ETS tables on top of them:

  * `:address_counters` — the display cache consumed by the API. Entries are
    seeded from the DB columns on read (`fetch/1`), incremented in place with
    the deltas of newly imported transactions and token transfers
    (`handle_new_data/3`), re-based from the DB by the consolidator
    (`refresh_from_consolidation/4`) and evicted a configurable TTL after
    their last authoritative base (seed or consolidator re-base), so any
    accumulated live-bump drift is bounded by the TTL even for addresses that
    are read constantly. Live bumps never create entries, so every cached
    value always sits on top of a real DB-derived base.

  * `:address_counters_dirty` — the consolidator work list: address hash bytes
    mapped to the maximum block number seen for the address since its last
    consolidation. Markers are written for every import (realtime and catchup)
    on nodes where the consolidator runs (`:indexer`/`:all` modes) and are
    capped at a configurable size — a dropped marker only delays consolidation
    until the address's next activity, it never corrupts the counters.

  On pure API nodes of split deployments the display cache is kept warm by the
  realtime `:transactions`/`:token_transfers` chain events (dirty markers are
  not written there — no local consolidator would ever drain them); on indexer
  and all-mode nodes `Explorer.Chain.Import` calls `handle_new_data/3`
  directly, so chain events are ignored there to avoid double counting.
  """

  use GenServer

  alias Explorer.Chain.Address.Counters
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.Helper
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.Hash

  @cache_name :address_counters
  @dirty_cache_name :address_counters_dirty

  @typedoc """
  Per-address contribution of a set of imported (or deleted) transactions and
  token transfers. `gas_in`/`gas_out` are tracked separately because which one
  is accumulated into the gas usage counter depends on the address type (see
  `Explorer.Chain.Address.Counters.gas_usage_direction_field/1`).
  """
  @type delta :: %{
          transactions_count: non_neg_integer(),
          token_transfers_count: non_neg_integer(),
          gas_in: non_neg_integer(),
          gas_out: non_neg_integer(),
          max_block_number: non_neg_integer()
        }

  @type counters :: %{
          transactions_count: non_neg_integer(),
          token_transfers_count: non_neg_integer(),
          gas_used: non_neg_integer()
        }

  @empty_delta %{transactions_count: 0, token_transfers_count: 0, gas_in: 0, gas_out: 0, max_block_number: 0}

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Helper.create_cache_table(@cache_name, write_concurrency: true)
    Helper.create_cache_table(@dirty_cache_name, write_concurrency: true)

    if Explorer.mode() == :api do
      Subscriber.to(:transactions, :realtime)
      Subscriber.to(:token_transfers, :realtime)
    end

    schedule_eviction()

    {:ok, %{}}
  end

  @doc """
  Returns the counters for the given address: the cached values when present,
  the `addresses` table columns of the given struct otherwise (seeding the
  cache along the way).

  An address whose counters were never calculated (all three columns are
  `NULL`) is reported as all-zero and marked dirty so that the consolidator
  computes its values ahead of the background backfill (on nodes with a local
  consolidator; on pure API nodes such addresses stay at zero until the
  backfill reaches them).
  """
  @spec fetch(Explorer.Chain.Address.t()) :: counters()
  def fetch(address) do
    if cache_table_exists?() do
      bytes = hash_bytes(address.hash)

      case snapshot(bytes) do
        nil -> seed_from_db(address, bytes)
        counters -> counters
      end
    else
      db_counters(address)
    end
  end

  @doc """
  Registers newly imported `transactions` and `token_transfers` in the cache:
  marks the involved addresses dirty for the consolidator and, when `live?` is
  `true` (realtime imports), increments the already-cached display values.
  """
  @spec handle_new_data([map()], [map()], boolean()) :: :ok
  def handle_new_data(transactions, token_transfers, live?) do
    if cache_table_exists?() do
      transactions
      |> compute_deltas(token_transfers)
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
  Computes per-address deltas for the given transactions and token transfers.

  Rows without a block number (pending transactions) are skipped. A
  transaction (or transfer) between an address and itself contributes once to
  the address counts, matching the `from = address OR to = address` semantics
  of the full aggregates. The optional `include?` predicate receives the
  address hash bytes and the row block number and can exclude single
  contributions (used to restrict deltas to blocks at or below an address
  consolidation watermark).
  """
  @spec compute_deltas([map()], [map()], (binary(), non_neg_integer() -> boolean())) :: %{binary() => delta()}
  def compute_deltas(transactions, token_transfers, include? \\ fn _hash_bytes, _block_number -> true end) do
    deltas = Enum.reduce(transactions, %{}, &add_transaction_delta(&2, &1, include?))

    Enum.reduce(token_transfers, deltas, &add_token_transfer_delta(&2, &1, include?))
  end

  defp add_transaction_delta(acc, %{block_number: nil}, _include?), do: acc

  defp add_transaction_delta(acc, transaction, include?) do
    block_number = transaction.block_number
    from_bytes = hash_bytes(transaction.from_address_hash)
    to_bytes = hash_bytes(transaction.to_address_hash)
    gas_used = Helper.gas_to_integer(transaction.gas_used)

    [from_bytes, to_bytes]
    |> participants(block_number, include?)
    |> Enum.reduce(acc, fn bytes, inner_acc ->
      add_delta(inner_acc, bytes, block_number, %{
        transactions_count: 1,
        token_transfers_count: 0,
        gas_in: if(bytes == to_bytes, do: gas_used, else: 0),
        gas_out: if(bytes == from_bytes, do: gas_used, else: 0)
      })
    end)
  end

  defp add_token_transfer_delta(acc, %{block_number: nil}, _include?), do: acc

  defp add_token_transfer_delta(acc, token_transfer, include?) do
    block_number = token_transfer.block_number

    [hash_bytes(token_transfer.from_address_hash), hash_bytes(token_transfer.to_address_hash)]
    |> participants(block_number, include?)
    |> Enum.reduce(acc, fn bytes, inner_acc ->
      add_delta(inner_acc, bytes, block_number, %{
        transactions_count: 0,
        token_transfers_count: 1,
        gas_in: 0,
        gas_out: 0
      })
    end)
  end

  defp participants(hash_bytes_list, block_number, include?) do
    hash_bytes_list
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.filter(&include?.(&1, block_number))
  end

  @doc """
  Increments the cached display values of the given address by the given
  delta. Only already-cached addresses are updated — live bumps never create
  entries, so a cached value always originates from a DB read.
  """
  @spec bump_live(binary(), delta()) :: :ok
  def bump_live(hash_bytes, delta) do
    if :ets.member(@cache_name, {hash_bytes, :transactions_count}) do
      gas_delta =
        case Helper.fetch_from_ets_cache(@cache_name, {hash_bytes, :gas_direction}) do
          :to_address_hash -> delta.gas_in
          :from_address_hash -> delta.gas_out
          _ -> 0
        end

      :ets.update_counter(@cache_name, {hash_bytes, :transactions_count}, delta.transactions_count)
      :ets.update_counter(@cache_name, {hash_bytes, :token_transfers_count}, delta.token_transfers_count)
      :ets.update_counter(@cache_name, {hash_bytes, :gas_used}, gas_delta)
    end

    :ok
  rescue
    # the entry was evicted between the membership check and the update
    ArgumentError -> :ok
  end

  @doc """
  Returns the currently cached display values of the given address or `nil`
  when the address is not cached.
  """
  @spec snapshot(binary()) :: counters() | nil
  def snapshot(hash_bytes) do
    with true <- cache_table_exists?(),
         [{_, transactions_count}] <- :ets.lookup(@cache_name, {hash_bytes, :transactions_count}),
         [{_, token_transfers_count}] <- :ets.lookup(@cache_name, {hash_bytes, :token_transfers_count}),
         [{_, gas_used}] <- :ets.lookup(@cache_name, {hash_bytes, :gas_used}) do
      %{transactions_count: transactions_count, token_transfers_count: token_transfers_count, gas_used: gas_used}
    else
      _ -> nil
    end
  end

  @doc """
  Re-bases the cached display values of the given address on the values just
  written to the DB by the consolidator.

  The write is an adjustment (`new value - snapshot`) rather than an
  overwrite, so live bumps applied concurrently — always for blocks above the
  consolidated range — survive on top of the new base.
  """
  @spec refresh_from_consolidation(binary(), :to_address_hash | :from_address_hash, counters(), counters() | nil) ::
          :ok
  def refresh_from_consolidation(hash_bytes, direction_field, new_values, snapshot) do
    if not is_nil(snapshot) and :ets.member(@cache_name, {hash_bytes, :transactions_count}) do
      :ets.update_counter(
        @cache_name,
        {hash_bytes, :transactions_count},
        new_values.transactions_count - snapshot.transactions_count
      )

      :ets.update_counter(
        @cache_name,
        {hash_bytes, :token_transfers_count},
        new_values.token_transfers_count - snapshot.token_transfers_count
      )

      :ets.update_counter(@cache_name, {hash_bytes, :gas_used}, new_values.gas_used - snapshot.gas_used)
      :ets.insert(@cache_name, {{hash_bytes, :gas_direction}, direction_field})
      :ets.insert(@cache_name, {{hash_bytes, :ts}, Helper.current_time()})
    end

    :ok
  rescue
    # the entry was evicted between the membership check and the update
    ArgumentError -> :ok
  end

  @doc """
  Drops the cached display values of the given addresses so that the next read
  re-seeds them from the DB. Used after out-of-band DB counter corrections
  (block re-fetch deltas, deep reorg resets).
  """
  @spec invalidate([binary()]) :: :ok
  def invalidate(hash_bytes_list) do
    if cache_table_exists?() do
      Enum.each(hash_bytes_list, &delete_display_entries/1)
    end

    :ok
  end

  @doc """
  Marks addresses dirty for the consolidator. Accepts a list of
  `{hash_bytes, block_number}` pairs; for every address the maximum seen block
  number is kept. The update is serialized through the cache process to avoid
  losing the maximum on concurrent writes.

  A no-op on nodes without a local consolidator (pure API mode) — markers
  would never be drained there.
  """
  @spec mark_dirty([{binary(), non_neg_integer()}]) :: :ok
  def mark_dirty(pairs) when is_list(pairs) do
    if consolidator_local?() do
      GenServer.cast(__MODULE__, {:mark_dirty, pairs})
    end

    :ok
  end

  @doc """
  Marks the given address dirty at the current maximum block number, asking
  the consolidator to (re)calculate its counters from scratch when
  `counters_updated_at` is `NULL` or incrementally otherwise.
  """
  @spec mark_dirty_at_max_block(Hash.Address.t()) :: :ok
  def mark_dirty_at_max_block(address_hash) do
    mark_dirty([{hash_bytes(address_hash), BlockNumber.get_max()}])
  end

  @doc """
  Returns `true` when there are no dirty markers (or the cache is not started).
  """
  @spec dirty_empty?() :: boolean()
  def dirty_empty? do
    :ets.whereis(@dirty_cache_name) == :undefined or :ets.info(@dirty_cache_name, :size) == 0
  end

  @doc """
  Starts (with a limit) or continues (with a previously returned continuation)
  a traversal of the dirty markers. Returns `{[{hash_bytes, block_number}], continuation}`
  or `:"$end_of_table"`.
  """
  @spec select_dirty(pos_integer() | :ets.continuation()) ::
          {[{binary(), non_neg_integer()}], :ets.continuation()} | :"$end_of_table"
  def select_dirty(limit) when is_integer(limit) do
    :ets.select(@dirty_cache_name, [{{:"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}], limit)
  end

  def select_dirty(continuation) do
    :ets.select(continuation)
  end

  @doc """
  Deletes the dirty markers of the given addresses unless a concurrent import
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
  Converts an address hash (or already-extracted hash bytes) to the binary key
  used in the cache tables.
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
        # the address's next activity (during initial sync all addresses are
        # covered by the backfill migration anyway)
        if :ets.info(@dirty_cache_name, :size) < max_dirty_markers() do
          :ets.insert(@dirty_cache_name, {bytes, block_number})
        end
    end
  end

  @impl true
  def handle_info({:chain_event, :transactions, :realtime, transactions}, state) do
    handle_new_data(transactions, [], true)
    {:noreply, state}
  end

  def handle_info({:chain_event, :token_transfers, :realtime, token_transfers}, state) do
    handle_new_data([], token_transfers, true)
    {:noreply, state}
  end

  def handle_info(:evict, state) do
    evict_stale_entries()
    schedule_eviction()
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp seed_from_db(address, bytes) do
    if is_nil(address.transactions_count) and is_nil(address.token_transfers_count) and is_nil(address.gas_used) do
      mark_dirty([{bytes, BlockNumber.get_max()}])

      %{transactions_count: 0, token_transfers_count: 0, gas_used: 0}
    else
      counters = db_counters(address)

      :ets.insert_new(@cache_name, [
        {{bytes, :transactions_count}, counters.transactions_count},
        {{bytes, :token_transfers_count}, counters.token_transfers_count},
        {{bytes, :gas_used}, counters.gas_used},
        {{bytes, :gas_direction}, Counters.gas_usage_direction_field(address)},
        {{bytes, :ts}, Helper.current_time()}
      ])

      counters
    end
  end

  defp db_counters(address) do
    %{
      transactions_count: address.transactions_count || 0,
      token_transfers_count: address.token_transfers_count || 0,
      gas_used: address.gas_used || 0
    }
  end

  defp add_delta(acc, bytes, block_number, contribution) do
    acc
    |> Map.put_new(bytes, @empty_delta)
    |> Map.update!(bytes, fn delta ->
      %{
        transactions_count: delta.transactions_count + contribution.transactions_count,
        token_transfers_count: delta.token_transfers_count + contribution.token_transfers_count,
        gas_in: delta.gas_in + contribution.gas_in,
        gas_out: delta.gas_out + contribution.gas_out,
        max_block_number: max(delta.max_block_number, block_number)
      }
    end)
  end

  defp delete_display_entries(bytes) do
    Enum.each([:transactions_count, :token_transfers_count, :gas_used, :gas_direction, :ts], fn key ->
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
    Application.get_env(:explorer, __MODULE__)[:max_dirty_markers] || 1_000_000
  end

  defp schedule_eviction do
    Process.send_after(self(), :evict, max(div(ttl(), 4), :timer.minutes(1)))
  end

  defp ttl do
    Application.get_env(:explorer, __MODULE__)[:ttl] || :timer.hours(2)
  end
end
