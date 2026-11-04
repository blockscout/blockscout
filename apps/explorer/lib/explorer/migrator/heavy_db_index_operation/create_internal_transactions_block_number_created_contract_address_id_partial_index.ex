# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockNumberCreatedContractAddressIdPartialIndex do
  @moduledoc """
  Create partial B-tree index `internal_transactions_block_number_created_contract_address_id_index` on `internal_transactions` table for (block_number, created_contract_address_id) columns where created_contract_address_id is not NULL.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsCreatedContractAddressIdIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :internal_transactions
  @index_name "internal_transactions_block_number_created_contract_address_id_index"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: [CreateInternalTransactionsCreatedContractAddressIdIndex.migration_name()]

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
  ON #{@table_name}(block_number, created_contract_address_id)
  WHERE (created_contract_address_id IS NOT NULL);
  """

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_address_ids_internal_transactions_indexes_finished(true)
  end
end
