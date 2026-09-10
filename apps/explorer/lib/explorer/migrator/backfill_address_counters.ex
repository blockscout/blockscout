# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.BackfillAddressCounters do
  @moduledoc """
  Backfills the incremental address counters: computes
  `addresses.transactions_count`, `addresses.token_transfers_count` and
  `addresses.gas_used` from scratch for every address that was never
  consolidated (`counters_updated_at IS NULL`) and stamps its consolidation
  watermark.

  Pre-existing column values were written by the legacy on-view counters at
  unknown block heights, so they cannot seed incremental updates and are
  recalculated. The migration walks the `addresses` primary key with a keyset
  cursor stored in the migration `meta`, so it resumes where it left off after
  a restart. Addresses consolidated concurrently (via the dirty-marker path of
  `Explorer.Chain.Cache.Counters.AddressCountersConsolidator`) are skipped by
  the `counters_updated_at IS NULL` guard.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  require Logger

  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Cache.Counters.AddressCountersConsolidator
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "backfill_address_counters"

  # extra cursor sweeps picking up addresses whose aggregates failed on a
  # previous pass (they keep a NULL watermark but the cursor already passed
  # them)
  @max_retry_passes 3

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    query =
      from(address in Address,
        where: is_nil(address.counters_updated_at),
        order_by: [asc: address.hash],
        limit: ^limit,
        select: address.hash
      )

    hashes =
      state
      |> Map.get("max_processed_hash")
      |> case do
        nil -> query
        cursor -> where(query, [address], address.hash > ^cursor)
      end
      |> Repo.all(timeout: :infinity)

    case List.last(hashes) do
      nil -> maybe_retry_pass(state)
      last_hash -> {hashes, Map.put(state, "max_processed_hash", to_string(last_hash))}
    end
  end

  defp maybe_retry_pass(state) do
    retry_passes = Map.get(state, "retry_passes", 0)

    if retry_passes < @max_retry_passes and Map.has_key?(state, "max_processed_hash") and
         Repo.exists?(from(address in Address, where: is_nil(address.counters_updated_at))) do
      last_unprocessed_identifiers(%{"retry_passes" => retry_passes + 1})
    else
      {[], state}
    end
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(address_hashes) do
    AddressCountersConsolidator.consolidate_addresses(address_hashes, await_safe_block())
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_backfill_address_counters_finished(true)
  end

  # Consolidation is not possible while the chain head is unknown or blocks
  # below it are still missing or pending a re-fetch counter correction. Wait
  # instead of skipping: the cursor must not advance past unprocessed
  # addresses.
  defp await_safe_block do
    case AddressCountersConsolidator.safe_block() do
      nil ->
        Logger.info("#{@migration_name} migration is waiting for a safe block to consolidate up to")
        Process.sleep(:timer.seconds(30))
        await_safe_block()

      safe_block ->
        safe_block
    end
  end
end
