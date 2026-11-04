# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateTransactionsCreatedContractAddressHashWPendingIndex do
  @moduledoc """
  Creates partial index "transactions_created_contract_address_hash_w_pending_index" on transactions (created_contract_address_hash, block_number ASC NULLS LAST, index ASC NULLS LAST, inserted_at ASC, hash DESC) WHERE created_contract_address_hash IS NOT NULL.
  """

  use Explorer.Migrator.HeavyDbIndexOperation
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :transactions
  @index_name "transactions_created_contract_address_hash_w_pending_index"
  @operation_type :create

  if @chain_type == :optimism do
    alias Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsOperatorFeeConstantIndex
    @impl HeavyDbIndexOperation
    def dependent_from_migrations do
      [DropTransactionsOperatorFeeConstantIndex.migration_name()]
    end
  else
    @impl HeavyDbIndexOperation
    def dependent_from_migrations do
      []
    end
  end

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
  ON #{@table_name} (created_contract_address_hash, block_number ASC NULLS LAST, "index" ASC NULLS LAST, inserted_at ASC, hash DESC)
  WHERE created_contract_address_hash IS NOT NULL;
  """

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_transactions_created_contract_address_hash_w_pending_index_finished(
      true
    )
  end
end
