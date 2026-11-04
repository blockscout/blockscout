# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateSmartContractsLanguageIndex do
  @moduledoc """
  Create B-tree index `smart_contracts_language_index` on `smart_contracts`
  table for the `language` column.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  @table_name :smart_contracts
  @index_name "smart_contracts_language_index"
  @operation_type :create
  @table_columns ["language"]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_smart_contracts_language_index_finished(true)
  end
end
