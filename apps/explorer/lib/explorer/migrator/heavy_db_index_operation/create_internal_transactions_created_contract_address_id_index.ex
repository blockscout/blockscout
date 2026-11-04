# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsCreatedContractAddressIdIndex do
  @moduledoc """
  Create B-tree index on `internal_transactions` table for `created_contract_address_id` column.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsToAddressIdPartialIndex

  @table_name :internal_transactions
  @index_name "internal_transactions_created_contract_address_id_index"
  @operation_type :create
  @table_columns ["created_contract_address_id"]

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: [CreateInternalTransactionsToAddressIdPartialIndex.migration_name()]
end
