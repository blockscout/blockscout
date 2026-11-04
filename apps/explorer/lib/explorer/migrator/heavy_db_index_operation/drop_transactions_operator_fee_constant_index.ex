# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsOperatorFeeConstantIndex do
  @moduledoc """
  Drops index "transactions_operator_fee_constant_index" btree (operator_fee_constant IS NULL).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  @table_name :transactions
  @index_name "transactions_operator_fee_constant_index"
  @operation_type :drop
end
