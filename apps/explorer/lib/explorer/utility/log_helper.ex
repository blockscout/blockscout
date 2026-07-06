# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.LogHelper do
  @moduledoc """
  Logs helping functions.
  """

  alias Explorer.Chain.Cache.BackgroundMigrations

  @spec primary_key_updated? :: boolean()
  def primary_key_updated? do
    BackgroundMigrations.get_heavy_indexes_update_logs_primary_key_finished()
  end

  @spec fill_optimized_fields_migration_finished? :: boolean()
  def fill_optimized_fields_migration_finished? do
    BackgroundMigrations.get_fill_logs_optimized_fields_finished()
  end

  @spec fill_optimized_fields_migration_started? :: boolean()
  def fill_optimized_fields_migration_started? do
    BackgroundMigrations.get_create_logs_block_number_transaction_index_index_unique_index_finished()
  end
end
