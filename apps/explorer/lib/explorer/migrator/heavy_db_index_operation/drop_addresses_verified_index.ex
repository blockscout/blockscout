# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropAddressesVerifiedIndex do
  @moduledoc """
  Drops index "addresses_verified_index" on the addresses table.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedIndex

  @table_name :addresses
  @index_name "addresses_verified_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [CreateAddressesVerifiedIndex.migration_name()]
  end
end
