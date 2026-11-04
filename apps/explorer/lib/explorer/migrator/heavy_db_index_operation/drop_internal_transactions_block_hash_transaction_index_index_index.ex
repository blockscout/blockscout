# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsBlockHashTransactionIndexIndexIndex do
  @moduledoc """
  Drops index "internal_transactions_block_hash_transaction_index_index_index" btree (block_hash, transaction_index, index).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{EmptyInternalTransactionsData, HeavyDbIndexOperation}

  alias Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsCreatedContractAddressHashPartialIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :internal_transactions
  @index_name "internal_transactions_block_hash_transaction_index_index_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [
      EmptyInternalTransactionsData.migration_name(),
      DropInternalTransactionsCreatedContractAddressHashPartialIndex.migration_name()
    ]
  end

  @impl HeavyDbIndexOperation
  def db_index_operation do
    with :ok <- HeavyDbIndexOperationHelper.cancel_index_creating_query(@index_name) do
      HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
    end
  end
end
