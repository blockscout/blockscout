# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.VacuumTokenTransfersAfterEip7708Sanitizing do
  @moduledoc """
  Vacuums the `token_transfers` table once `Explorer.Migrator.SanitizeEip7708TokenTransfers`
  has deleted the token transfers of the EIP-7708 `SYSTEM_ADDRESS` (`0xffff...fffe`).

  The system address is the greatest possible value of `token_contract_address_hash`, so
  the index entries of the deleted token transfers make up one contiguous tail at the
  very end of the indexes led by this column. Until the tail is removed, every time the
  planner needs the actual maximum of the column (e.g. when it estimates a join of
  `token_transfers` with `tokens`), it walks through all of these dead entries, which
  adds seconds to the planning of queries that otherwise execute in milliseconds.

  The vacuum removes the dead rows from the table. It isn't enough on its own on a large
  table: PostgreSQL skips index vacuuming when less than 2% of the table pages hold dead
  rows, so the affected indexes are rebuilt afterwards by
  `Explorer.Migrator.HeavyDbIndexOperation.ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex`
  and
  `Explorer.Migrator.HeavyDbIndexOperation.ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex`.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{HeavyDbIndexOperation, SanitizeEip7708TokenTransfers}

  @table_name :token_transfers
  @operation_type :vacuum
  @migration_name_suffix "after_eip7708_sanitizing"

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      SanitizeEip7708TokenTransfers.migration_name()
    ]
end
