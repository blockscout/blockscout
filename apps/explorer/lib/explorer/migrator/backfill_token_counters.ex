# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.BackfillTokenCounters do
  @moduledoc """
  Backfills the incremental token counters: recalculates
  `tokens.transfer_count` (full count bounded by the consolidation safe block)
  and `tokens.holder_count` (snapshot-relative full recount — normalizing the
  drift accumulated by the legacy delta semantics) for every token that was
  never consolidated (`counters_updated_at IS NULL`) and stamps its
  consolidation watermark.

  The migration walks the `tokens` primary key with a keyset cursor stored in
  the migration `meta`, so it resumes where it left off after a restart.
  Tokens consolidated concurrently (via the dirty-marker path of
  `Explorer.Chain.Cache.Counters.TokenCountersConsolidator`) are skipped by
  the `counters_updated_at IS NULL` guard.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  require Logger

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Cache.Counters.{Consolidation, TokenCountersConsolidator}
  alias Explorer.Chain.Token
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "backfill_token_counters"

  # extra cursor sweeps picking up tokens whose recalculation failed on a
  # previous pass (they keep a NULL watermark but the cursor already passed
  # them)
  @max_retry_passes 3

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    query =
      from(token in Token,
        where: is_nil(token.counters_updated_at),
        order_by: [asc: token.contract_address_hash],
        limit: ^limit,
        select: token.contract_address_hash
      )

    hashes =
      state
      |> Map.get("max_processed_hash")
      |> case do
        nil -> query
        cursor -> where(query, [token], token.contract_address_hash > ^cursor)
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
         Repo.exists?(from(token in Token, where: is_nil(token.counters_updated_at))) do
      last_unprocessed_identifiers(%{"retry_passes" => retry_passes + 1})
    else
      {[], state}
    end
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(contract_address_hashes) do
    TokenCountersConsolidator.consolidate_tokens(contract_address_hashes, await_safe_block())
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_backfill_token_counters_finished(true)
  end

  # Consolidation is not possible while the chain head is unknown or blocks
  # below it are still missing or pending a re-fetch counter correction. Wait
  # instead of skipping: the cursor must not advance past unprocessed tokens.
  defp await_safe_block do
    case Consolidation.safe_block() do
      nil ->
        Logger.info("#{@migration_name} migration is waiting for a safe block to consolidate up to")
        Process.sleep(:timer.seconds(30))
        await_safe_block()

      safe_block ->
        safe_block
    end
  end
end
