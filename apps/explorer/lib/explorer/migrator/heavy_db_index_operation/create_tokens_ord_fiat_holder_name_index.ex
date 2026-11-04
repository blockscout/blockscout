# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateTokensOrdFiatHolderNameIndex do
  @moduledoc """
  Create B-tree index `idx_tokens_ord_fiat_holder_name` on `tokens` table for
  (`fiat_value DESC NULLS LAST`, `holder_count DESC NULLS LAST`, `name`).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateTokensOrdMcapFiatHolderNameIndex

  @table_name :tokens
  @index_name "idx_tokens_ord_fiat_holder_name"
  @operation_type :create
  @table_columns [
    "fiat_value DESC NULLS LAST",
    "holder_count DESC NULLS LAST",
    "name"
  ]

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [CreateTokensOrdMcapFiatHolderNameIndex.migration_name()]
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_idx_tokens_ord_fiat_holder_name_finished(true)
  end
end
