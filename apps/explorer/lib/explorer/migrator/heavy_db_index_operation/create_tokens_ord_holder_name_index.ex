# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateTokensOrdHolderNameIndex do
  @moduledoc """
  Create B-tree index `idx_tokens_ord_holder_name` on `tokens` table for
  (`holder_count DESC NULLS LAST`, `name`).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateTokensOrdFiatHolderNameIndex

  @table_name :tokens
  @index_name "idx_tokens_ord_holder_name"
  @operation_type :create
  @table_columns ["holder_count DESC NULLS LAST", "name"]

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [CreateTokensOrdFiatHolderNameIndex.migration_name()]
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_idx_tokens_ord_holder_name_finished(true)
  end
end
