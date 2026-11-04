# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsBlockNumberCreatedContractAddressHashIndex do
  @moduledoc """
  Drops index "internal_transactions_block_number_created_contract_address_hash" btree (block_number, created_contract_address_hash) WHERE (created_contract_address_hash IS NOT NULL).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{FillInternalTransactionsAddressIds, HeavyDbIndexOperation}

  @table_name :internal_transactions
  @index_name "internal_transactions_block_number_created_contract_address_hash"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: [FillInternalTransactionsAddressIds.migration_name()]
end
