# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsFromAddressHashPartialIndex do
  @moduledoc """
  Drops index "internal_transactions_from_address_hash_partial_index" btree (from_address_hash, block_number DESC, transaction_index DESC, index DESC) WHERE ((((type)::text = 'call'::text) AND (index > 0)) OR ((type)::text <> 'call'::text)).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{FillInternalTransactionsAddressIds, HeavyDbIndexOperation}

  alias Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsCreatedContractAddressHashIndex

  @table_name :internal_transactions
  @index_name "internal_transactions_from_address_hash_partial_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      FillInternalTransactionsAddressIds.migration_name(),
      DropInternalTransactionsCreatedContractAddressHashIndex.migration_name()
    ]
end
