# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsToAddressHashPartialIndex do
  @moduledoc """
  Drops index "internal_transactions_to_address_hash_partial_index" btree (to_address_hash, block_number DESC, transaction_index DESC, index DESC) WHERE ((((type)::text = 'call'::text) AND (index > 0)) OR ((type)::text <> 'call'::text)).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{FillInternalTransactionsAddressIds, HeavyDbIndexOperation}

  alias Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsFromAddressHashPartialIndex

  @table_name :internal_transactions
  @index_name "internal_transactions_to_address_hash_partial_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      FillInternalTransactionsAddressIds.migration_name(),
      DropInternalTransactionsFromAddressHashPartialIndex.migration_name()
    ]
end
