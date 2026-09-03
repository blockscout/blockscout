# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.RenameAddressCountersRefetchBlocks do
  use Ecto.Migration

  # the block re-fetch corrections queue is shared by the address AND token
  # counters consolidation, so the address-scoped name is dropped
  def change do
    rename(table(:address_counters_refetch_blocks), to: table(:counters_refetch_blocks))

    execute(
      "ALTER INDEX address_counters_refetch_blocks_pkey RENAME TO counters_refetch_blocks_pkey",
      "ALTER INDEX counters_refetch_blocks_pkey RENAME TO address_counters_refetch_blocks_pkey"
    )
  end
end
