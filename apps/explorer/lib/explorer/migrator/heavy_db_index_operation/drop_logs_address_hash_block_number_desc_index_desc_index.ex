# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashBlockNumberDescIndexDescIndex do
  @moduledoc """
  Drops B-tree index `logs_address_hash_block_number_DESC_index_DESC_index` on `logs` table for (`address_hash`, `block_number DESC`, `index DESC`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{FillLogsOptimizedFields, HeavyDbIndexOperation}

  @table_name :logs
  @index_name "logs_address_hash_block_number_DESC_index_DESC_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: [FillLogsOptimizedFields.migration_name()]
end
