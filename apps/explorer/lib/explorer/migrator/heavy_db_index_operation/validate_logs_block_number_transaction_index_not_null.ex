# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.ValidateLogsBlockNumberTransactionIndexNotNull do
  @moduledoc """
  Validate `NOT NULL` constraints for `logs` (`block_number`, `transaction_index`).

  On Celo, logs may be emitted by the block itself, not by a transaction, so `transaction_index`
  stays nullable there and only `block_number` is validated.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  use Utils.CompileTimeEnvHelper, chain_identity: [:explorer, :chain_identity]

  alias Explorer.Migrator.{FillLogsOptimizedFields, HeavyDbIndexOperation}

  @table_name :logs
  @index_name "logs_not_null_constraints"
  @columns (case @chain_identity do
              {:optimism, :celo} -> ["block_number"]
              _ -> ["block_number", "transaction_index"]
            end)
  @operation_type :create

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      FillLogsOptimizedFields.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.validate_not_null_db_index_operation(@table_name, @columns)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.validate_not_null_check_db_index_operation_progress(@table_name, @index_name, @columns)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.validate_not_null_db_index_operation_status(@table_name, @columns)
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    HeavyDbIndexOperationHelper.validate_not_null_restart_db_index_operation(@table_name, @columns)
  end
end
