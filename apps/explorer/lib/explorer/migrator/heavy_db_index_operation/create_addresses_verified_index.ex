# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedIndex do
  @moduledoc """
  Create partial B-tree index on `addresses` table filtering by `verified = true`.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :addresses
  @index_name "addresses_verified_index"
  @operation_type :create

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
  ON #{@table_name} ((1))
  WHERE verified = true;
  """

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_addresses_verified_index_finished(true)
  end
end
