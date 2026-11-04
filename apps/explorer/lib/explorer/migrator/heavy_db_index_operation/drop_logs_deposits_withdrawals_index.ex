# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsDepositsWithdrawalsIndex do
  @moduledoc """
  Drops partial B-tree index `logs_deposits_withdrawals_index` on `logs` table for (`transaction_hash`, `block_hash`, `index`, `address_hash`) columns, filtered by first_topic IN
                                                                      ('\\xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c',
                                                                       '\\x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65')
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{FillLogsOptimizedFields, HeavyDbIndexOperation}

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    DropLogsAddressHashBlockNumberDescIndexDescIndex,
    DropLogsAddressHashFirstTopicBlockNumberIndexIndex
  }

  @table_name :logs
  @index_name "logs_deposits_withdrawals_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      FillLogsOptimizedFields.migration_name(),
      DropLogsAddressHashBlockNumberDescIndexDescIndex.migration_name(),
      DropLogsAddressHashFirstTopicBlockNumberIndexIndex.migration_name()
    ]
end
