# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsToAddressIdPartialIndex do
  @moduledoc """
  Create partial B-tree index `internal_transactions_to_address_id_partial_index` on `internal_transactions` table for (`to_address_id`, `block_number` DESC, `transaction_index` DESC, `index` DESC) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsFromAddressIdPartialIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :internal_transactions
  @index_name "internal_transactions_to_address_id_partial_index"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: [CreateInternalTransactionsFromAddressIdPartialIndex.migration_name()]

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
  ON #{@table_name}(to_address_id ASC, block_number DESC, transaction_index DESC, index DESC)
  WHERE ((type = 'call' AND index > 0) OR type != 'call');
  """
end
