# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropTokenInstancesTokenIdIndex do
  @moduledoc """
  Drops index "token_instances_token_id_index" btree (token_id).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  @table_name :token_instances
  @index_name "token_instances_token_id_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    []
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_token_instances_token_id_index_finished(true)
  end
end
