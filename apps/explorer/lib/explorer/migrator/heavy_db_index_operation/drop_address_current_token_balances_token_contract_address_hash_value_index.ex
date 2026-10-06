# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropAddressCurrentTokenBalancesTokenContractAddressHashValueIndex do
  @moduledoc """
  Drops the old token holders partial index on the `address_current_token_balances`
  table: `(token_contract_address_hash, value DESC, address_hash DESC)` filtered by
  `address_hash != burn address AND value > 0`.

  The index is identified by its content (columns and predicate) rather than by
  name: the 20240404102510 migration produced
  "address_current_token_balances_token_contract_address_hash__val" (a 63-byte
  truncation), but on some instances the same index exists under a different,
  manually assigned name. Every index matching the content is dropped.

  Superseded by "address_current_token_balances_token_holders_index" (same
  columns, wider partial predicate additionally covering
  `token_type = 'ERC-7984'` rows), so it waits for
  `CreateAddressCurrentTokenBalancesTokenHoldersIndex` to complete first.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Ecto.Adapters.SQL
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateAddressCurrentTokenBalancesTokenHoldersIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper
  alias Explorer.Repo

  @table_name :address_current_token_balances
  # the name produced by the 20240404102510 migration; used as the stable
  # migration identity, while the actual name(s) to drop are discovered by
  # index content (see `redundant_index_names/0`)
  @index_name "address_current_token_balances_token_contract_address_hash__val"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [CreateAddressCurrentTokenBalancesTokenHoldersIndex.migration_name()]
  end

  @impl HeavyDbIndexOperation
  def db_index_operation do
    redundant_index_names()
    |> Enum.reduce(:ok, fn index_name, acc ->
      case HeavyDbIndexOperationHelper.safely_drop_db_index(index_name) do
        :ok -> acc
        :error -> :error
      end
    end)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    redundant_index_names()
    |> Enum.map(fn index_name ->
      operation = HeavyDbIndexOperationHelper.drop_index_query_string(index_name)
      HeavyDbIndexOperationHelper.check_db_index_operation_progress(index_name, operation)
    end)
    |> Enum.max_by(
      fn
        :in_progress -> 2
        :unknown -> 1
        :finished_or_not_started -> 0
      end,
      fn -> :finished_or_not_started end
    )
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    redundant_index_names()
    |> Enum.map(&HeavyDbIndexOperationHelper.db_index_dropping_status/1)
    |> Enum.max_by(
      fn
        :unknown -> 3
        :not_initialized -> 2
        :not_completed -> 1
        :completed -> 0
      end,
      fn -> :completed end
    )
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    db_index_operation()
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache, do: :ok

  # Finds indexes on the table matching the old token holders index content:
  # the exact column list, the burn address filter, the `value > 0` condition
  # (both renderings pg_get_indexdef is known to produce), and no `token_type`
  # in the predicate (which distinguishes the superseding index). The lookup is
  # constrained to the current schema, where the unqualified DROP INDEX issued
  # by `safely_drop_db_index/1` resolves.
  @redundant_index_names_query """
  SELECT indexname FROM pg_indexes
  WHERE schemaname = current_schema()
    AND tablename = $1
    AND indexdef LIKE '%(token#_contract#_address#_hash, value DESC, address#_hash DESC)%' ESCAPE '#'
    AND indexdef LIKE '%WHERE%'
    AND indexdef LIKE '%0000000000000000000000000000000000000000%'
    AND (indexdef LIKE '%value > (0)::numeric%' OR indexdef LIKE '%value > 0::numeric%')
    AND indexdef NOT LIKE '%token_type%';
  """

  defp redundant_index_names do
    case SQL.query(Repo, @redundant_index_names_query, [to_string(@table_name)]) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        List.flatten(rows)

      {:error, error} ->
        Logger.error("Failed to look up old token holders indexes: #{inspect(error)}")
        []
    end
  end
end
