# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsDepositsWithdrawalsIndex do
  @moduledoc """
  Drops partial B-tree index `logs_deposits_withdrawals_index` on `logs` table for (`transaction_hash`, `block_hash`, `index`, `address_hash`) columns, filtered by first_topic IN
                                                                      ('\\xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c',
                                                                       '\\x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65')
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{FillLogsTransactionIndexAddressId, HeavyDbIndexOperation, MigrationStatus}

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    DropLogsAddressHashBlockNumberDescIndexDescIndex,
    DropLogsAddressHashFirstTopicBlockNumberIndexIndex
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :logs
  @index_name "logs_deposits_withdrawals_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      FillLogsTransactionIndexAddressId.migration_name(),
      DropLogsAddressHashBlockNumberDescIndexDescIndex.migration_name(),
      DropLogsAddressHashFirstTopicBlockNumberIndexIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    operation = HeavyDbIndexOperationHelper.drop_index_query_string(@index_name)
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, operation)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.db_index_dropping_status(@index_name)
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache, do: :ok
end
