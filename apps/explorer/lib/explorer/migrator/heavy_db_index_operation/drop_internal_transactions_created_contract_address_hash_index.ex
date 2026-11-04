# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsCreatedContractAddressHashIndex do
  @moduledoc """
  Drops index "internal_transactions_created_contract_address_hash_index" btree (created_contract_address_hash).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{FillInternalTransactionsAddressIds, HeavyDbIndexOperation}
  alias Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsBlockNumberCreatedContractAddressHashIndex

  @table_name :internal_transactions
  @index_name "internal_transactions_created_contract_address_hash_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      FillInternalTransactionsAddressIds.migration_name(),
      DropInternalTransactionsBlockNumberCreatedContractAddressHashIndex.migration_name()
    ]
end
