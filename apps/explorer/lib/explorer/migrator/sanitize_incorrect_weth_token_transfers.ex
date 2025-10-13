defmodule Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers do
  @moduledoc """
    This migrator will delete all incorrect WETH token transfers. As incorrect we consider:
      - WETH withdrawals and WETH deposits emitted by tokens which are not in `WHITELISTED_WETH_CONTRACTS` env
      - WETH withdrawal or WETH deposit which has sibling token transfer within the same block and transaction, with the same amount, same from and to addresses, same token contract addresses. (We consider such pairs as duplicates)
  """

  use Explorer.Migrator.FillingMigration

  require Logger

  import Explorer.QueryHelper, only: [select_ctid: 1, join_on_ctid: 2]

  alias Explorer.Migrator.FillingMigration
  alias Explorer.Chain.{TokenTransfer, Log}
  alias Ecto.Adapters.SQL
  alias Explorer.Repo

  @migration_name "sanitize_incorrect_weth_transfers"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def unprocessed_data_query(_state) do
    view_candidates =
      from(
        vc in materialized_view_name(),
        select: %{
          transaction_hash: field(vc, :transaction_hash),
          block_hash: field(vc, :block_hash),
          log_index: field(vc, :log_index)
        },
        where: fragment(~s|?."ctid" BETWEEN '(?,0)' AND '(?,65535)'|, vc, 0, 0)
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
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      state
      |> unprocessed_data_query()
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
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
          -- it is important that ordering corresonds to the 
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

  defp materialized_view_name do
    "#{@migration_name}_view"
  end

  # @impl true
  # def handle_continue(:ok, state) do
  #   case MigrationStatus.fetch(@migration_name) do
  #     %{status: "completed"} ->
  #       {:stop, :normal, state}

  #     %{status: "wait_for_enabling_weth_filtering"} ->
  #       if weth_token_transfers_filtering_enabled() do
  #         schedule_batch_migration(0)
  #         MigrationStatus.set_status(@migration_name, "started")
  #         {:noreply, Map.put(state, "step", "delete_not_whitelisted_weth_transfers")}
  #       else
  #         {:stop, :normal, state}
  #       end

  #     status ->
  #       state = (status && status.meta) || %{"step" => "delete_duplicates"}

  #       if is_nil(status) do
  #         MigrationStatus.set_status(@migration_name, "started")
  #         MigrationStatus.update_meta(@migration_name, state)
  #       end

  #       schedule_batch_migration(0)
  #       {:noreply, state}
  #   end
  # end

  # @impl true
  # def handle_info(:migrate_batch, %{"step" => step} = state) do
  #   if step == "delete_not_whitelisted_weth_transfers" and !weth_token_transfers_filtering_enabled() do
  #     MigrationStatus.set_status(@migration_name, "wait_for_enabling_weth_filtering")
  #     {:stop, :normal, state}
  #   else
  #     process_batch(state)
  #   end
  # end

  # defp process_batch(%{"step" => step} = state) do
  #   case last_unprocessed_identifiers(step) do
  #     [] ->
  #       case step do
  #         "delete_duplicates" ->
  #           Logger.info(
  #             "SanitizeIncorrectWETHTokenTransfers deletion of duplicates finished, continuing with deletion of not whitelisted weth transfers"
  #           )

  #           schedule_batch_migration()

  #           new_state = %{"step" => "delete_not_whitelisted_weth_transfers"}
  #           MigrationStatus.update_meta(@migration_name, new_state)

  #           {:noreply, new_state}

  #         "delete_not_whitelisted_weth_transfers" ->
  #           Logger.info(
  #             "SanitizeIncorrectWETHTokenTransfers deletion of not whitelisted weth transfers finished. Sanitizing is completed."
  #           )

  #           MigrationStatus.set_status(@migration_name, "completed")
  #           MigrationStatus.set_meta(@migration_name, nil)

  #           {:stop, :normal, state}
  #       end

  #     identifiers ->
  #       identifiers
  #       |> Enum.chunk_every(batch_size())
  #       |> Enum.map(&run_task/1)
  #       |> Task.await_many(:infinity)

  #       schedule_batch_migration()

  #       {:noreply, state}
  #   end
  # end

  # defp last_unprocessed_identifiers(step) do
  #   limit = batch_size() * concurrency()

  #   step
  #   |> unprocessed_identifiers()
  #   |> limit(^limit)
  #   |> Repo.all(timeout: :infinity)
  # end

  # defp unprocessed_identifiers("delete_duplicates") do
  #   weth_transfers =
  #     token_transfers_with_logs_query()
  #     |> where(^Log.first_topic_is_deposit_or_withdrawal_signature())

  #   not_weth_transfers =
  #     token_transfers_with_logs_query()
  #     |> where(^Log.first_topic_is_not_deposit_or_withdrawal_signature())

  #   from(
  #     weth_tt in subquery(weth_transfers),
  #     inner_join: tt in subquery(not_weth_transfers),
  #     on: weth_tt.block_hash == tt.block_hash and weth_tt.transaction_hash == tt.transaction_hash,
  #     where:
  #       weth_tt.log_index != tt.log_index and weth_tt.token_contract_address_hash == tt.token_contract_address_hash and
  #         weth_tt.to_address_hash == tt.to_address_hash and weth_tt.from_address_hash == tt.from_address_hash and
  #         weth_tt.amount == tt.amount,
  #     select: {weth_tt.transaction_hash, weth_tt.block_hash, weth_tt.log_index}
  #   )
  # end

  # defp unprocessed_identifiers("delete_not_whitelisted_weth_transfers") do
  #   token_transfers_with_logs_query()
  #   |> where(^Log.first_topic_is_deposit_or_withdrawal_signature())
  #   |> where([tt], tt.token_contract_address_hash not in ^whitelisted_weth_contracts())
  #   |> select([tt], {tt.transaction_hash, tt.block_hash, tt.log_index})
  # end

  # defp token_transfers_with_logs_query do
  #   from(
  #     tt in TokenTransfer,
  #     left_join: l in Log,
  #     as: :log,
  #     on: tt.block_hash == l.block_hash and tt.transaction_hash == l.transaction_hash and tt.log_index == l.index
  #   )
  # end

  # defp whitelisted_weth_contracts do
  #   Application.get_env(:explorer, Explorer.Chain.TokenTransfer)[:whitelisted_weth_contracts]
  # end

  # defp weth_token_transfers_filtering_enabled do
  #   Application.get_env(:explorer, Explorer.Chain.TokenTransfer)[:weth_token_transfers_filtering_enabled]
  # end
end
