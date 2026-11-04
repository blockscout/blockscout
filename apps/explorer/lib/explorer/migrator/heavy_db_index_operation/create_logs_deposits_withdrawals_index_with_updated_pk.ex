# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsDepositsWithdrawalsIndexWithUpdatedPk do
  @moduledoc """
  Create partial B-tree index `logs_deposits_withdrawals_index_with_updated_pk` on `logs` table for (`transaction_index`, `block_number`, `index`, `address_id`) columns, filtered by first_topic IN
                                                                      ('\\xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c',
                                                                       '\\x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65')
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateLogsAddressIdFirstTopicBlockNumberIndexIndex,
    UpdateLogsPrimaryKey
  }

  @table_name :logs
  @index_name "logs_deposits_withdrawals_index_with_updated_pk"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [CreateLogsAddressIdFirstTopicBlockNumberIndexIndex.migration_name(), UpdateLogsPrimaryKey.migration_name()]

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
   ON #{@table_name} (transaction_index, block_number, index, address_id) where first_topic_id IN (2, 3);
  """

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_logs_deposits_withdrawals_index_with_updated_pk_finished(true)
  end
end
