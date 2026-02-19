defmodule Explorer.Migrator.SanitizeIncorrectWETHTokenTransfersDuplicates do
  @moduledoc """
    This migrator sanitizes WETH withdrawal or WETH deposit which has sibling token transfer
    within the same block and transaction, with the same amount, same from and to addresses,
    same token contract addresses (We consider such pairs as duplicates)
  """

  use Explorer.Migrator.FillingMigration

  require Logger

  import Explorer.QueryHelper, only: [select_ctid: 1, join_on_ctid: 2]

  alias Explorer.Migrator.FillingMigration
  alias Explorer.Chain.{TokenTransfer, Log}
  alias Ecto.Adapters.SQL
  alias Explorer.Repo

  @prvious_migration_name "sanitize_incorrect_weth_transfers"

  @migration_name "sanitize_incorrect_weth_transfers_duplicates"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def unprocessed_data_query(%{"number_of_pages" => number_of_pages, "next_page" => next_page} = _state) do
    {range_start, range_end} = batch_pages_range(number_of_pages, next_page)

    view_candidates =
      from(
        vc in materialized_view_name(),
        select: %{
          transaction_hash: field(vc, :transaction_hash),
          block_hash: field(vc, :block_hash),
          log_index: field(vc, :log_index)
        },
        # couldn't find an easier way to specify custom ctid inside the fragment
        where:
          fragment(
            ~s|?."ctid" BETWEEN format('(%s,0)', ?::bigint)::tid AND format('(%s,65535)', ?::bigint)::tid|,
            vc,
            ^range_start,
            ^range_end
          )
      )

    deposit_and_withdrawal_token_transfers =
      from(tt in TokenTransfer,
        join: vc in subquery(view_candidates),
        on:
          tt.transaction_hash == vc.transaction_hash and
            tt.block_hash == vc.block_hash and
            tt.log_index == vc.log_index,
        select: %{
          transaction_hash: tt.transaction_hash,
          block_hash: tt.block_hash,
          log_index: tt.log_index,
          token_contract_address_hash: tt.token_contract_address_hash,
          to_address_hash: tt.to_address_hash,
          from_address_hash: tt.from_address_hash,
          amount: tt.amount
        }
      )

    duplicated_deposits_and_withdrawals =
      from(tt in TokenTransfer,
        as: :tt,
        join: dw in subquery(deposit_and_withdrawal_token_transfers),
        on:
          tt.transaction_hash == dw.transaction_hash and
            tt.block_hash == dw.block_hash and
            tt.log_index != dw.log_index,
        where:
          tt.token_contract_address_hash == dw.token_contract_address_hash and
            tt.from_address_hash == dw.from_address_hash and
            tt.to_address_hash == dw.to_address_hash and
            tt.amount == dw.amount,
        where:
          exists(
            from(log in Log,
              select: 1,
              where:
                parent_as(:tt).transaction_hash == log.transaction_hash and
                  parent_as(:tt).block_hash == log.block_hash and
                  parent_as(:tt).log_index == log.index and
                  log.first_topic not in [
                    ^TokenTransfer.weth_deposit_signature(),
                    ^TokenTransfer.weth_withdrawal_signature()
                  ]
            )
          ),
        select: %{transaction_hash: dw.transaction_hash, block_hash: dw.block_hash, log_index: dw.log_index}
      )

    duplicated_deposits_and_withdrawals
  end

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"number_of_pages" => number_of_pages, "next_page" => next_page} = state) do
    limit = batch_size() * concurrency()

    ids =
      state
      |> unprocessed_data_query()
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {_range_start, current_range_end} = batch_pages_range(number_of_pages, next_page)
    new_next_page = current_range_end + 1
    new_state = Map.put(state, "next_page", new_next_page)

    case ids do
      [] when new_next_page < number_of_pages ->
        # No unrpocessed rows inside the current range of pages,
        # but there are still some pages to process
        MigrationStatus.update_meta(migration_name(), new_state)
        last_unprocessed_identifiers(new_state)

      [] ->
        # No unprocessed pages left and the migration is completed.
        # We return the new state as we want to store the total number of processed pages
        # as migration metadata after it is completed
        {[], new_state}

      ids ->
        # Some rows were extracted from the current range, but there can be more
        # not returned due to the `limit` statement. On the next iteration we will try
        # to check the current range once again to find such rows.
        {ids, state}
    end
  end

  @impl FillingMigration
  def update_batch(token_transfers) do
    base_lock_query =
      from(
        tt in TokenTransfer,
        select: select_ctid(tt),
        order_by: [asc: tt.transaction_hash, asc: tt.log_index],
        lock: "FOR UPDATE"
      )

    locked_token_transfers_query =
      Enum.reduce(token_transfers, base_lock_query, fn token_transfer, accumulated_query ->
        %{
          transaction_hash: transaction_hash,
          block_hash: block_hash,
          log_index: log_index
        } = token_transfer

        from(tt in accumulated_query,
          or_where:
            tt.transaction_hash == ^transaction_hash and tt.block_hash == ^block_hash and tt.log_index == ^log_index
        )
      end)

    delete_query =
      from(
        tt in TokenTransfer,
        inner_join: locked_tt in subquery(locked_token_transfers_query),
        on: join_on_ctid(tt, locked_tt)
      )

    Repo.delete_all(delete_query, timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok

  @impl FillingMigration
  def on_finish(%{"materialized_view_created" => true} = state) do
    SQL.query(
      Repo,
      """
        DROP MATERIALIZED VIEW IF EXISTS "#{materialized_view_name()}";
      """
    )

    Map.put(state, "materialized_view_dropped", true)
  end

  def on_finish(state) do
    state
  end

  @impl FillingMigration
  def before_start(%{"materialized_view_created" => true} = state) do
    state
  end

  def before_start(state) do
    # Postgres accepts byte values encoded with "\x" prefix.
    # The signatures returned by TokenTransfer module encodes them with "0x" prefix instead.
    escaped_deposit_signature = TokenTransfer.weth_deposit_signature() |> String.replace("0x", "\\x", global: false)

    escaped_withdrawal_signature =
      TokenTransfer.weth_withdrawal_signature() |> String.replace("0x", "\\x", global: false)

    # We cannot use prepared statements in materialized view definitons, so we have to write the query in raw SQL format.
    SQL.query(
      Repo,
      """
        CREATE MATERIALIZED VIEW IF NOT EXISTS "#{materialized_view_name()}" AS
          SELECT st0."transaction_hash",
                 st0."block_hash",
                 st0."log_index"
          FROM "token_transfers" st0
            LEFT JOIN "logs" sl1
              ON st0."transaction_hash" = sl1."transaction_hash" AND st0."block_hash" = sl1."block_hash" AND st0."log_index" = sl1."index"
          WHERE sl1."first_topic" = ANY (ARRAY[
            '#{escaped_deposit_signature}'::bytea, '#{escaped_withdrawal_signature}'::bytea
          ])
          -- it is important that ordering corresonds to the `token_transfers_pkey` index
          -- as we further will iterate the view rows in the same order they are stored on the disk
          -- and join them with the index values. Having view and index in the same order allows for
          -- much faster iterations.
          ORDER BY st0."transaction_hash", st0."block_hash", st0."log_index";
      """
    )

    {:ok, %{rows: [[number_of_pages]]}} =
      SQL.query(
        Repo,
        """
          SELECT pg_relation_size('#{materialized_view_name()}'::regclass) / current_setting('block_size')::bigint AS "number_of_pages";
        """
      )

    state
    |> Map.put("materialized_view_created", true)
    |> Map.put("number_of_pages", number_of_pages)
    |> Map.put("next_page", 0)
  end

  @impl FillingMigration
  def ready_to_start() do
    previous_migration_status = MigrationStatus.fetch(@prvious_migration_name)
    previous_migration_state = (previous_migration_status && previous_migration_status.meta) || %{}
    completed_by_split = previous_migration_state["completed.by_split"] || false

    case previous_migration_status do
      %{status: "completed"} when completed_by_split ->
        {:ok}

      %{status: "completed"} ->
        {:completed}

      _ ->
        new_previous_migration_state = Map.put(previous_migration_state, "completed.by_split", true)
        MigrationStatus.update_meta(@prvious_migration_name, new_previous_migration_state)
        MigrationStatus.set_status(@prvious_migration_name, "completed")
        {:ok}
    end
  end

  defp materialized_view_name do
    "#{@migration_name}_view"
  end

  defp batch_pages_range(number_of_pages, next_page) do
    range_start = next_page
    # When using sql `BETWEEN .. AND ..` statement it includes both ends of the given range.
    # So we have to subtract 1 in order for the number of pages to be exactly `batch_pages_size`.
    range_end = min(next_page + batch_pages_size() - 1, number_of_pages - 1)
    {range_start, range_end}
  end

  defp batch_pages_size do
    default = 100

    Application.get_env(:explorer, __MODULE__)[:batch_pages_size] || default
  end
end
