# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex do
  @moduledoc """
  Rebuilds index "token_transfers_token_contract_address_hash__block_number_DESC_" btree
  (token_contract_address_hash, block_number DESC, log_index DESC).

  The rebuild removes the entries of the token transfers deleted by
  `Explorer.Migrator.SanitizeEip7708TokenTransfers` from the index, see
  `Explorer.Migrator.HeavyDbIndexOperation.VacuumTokenTransfersAfterEip7708Sanitizing`
  for the details.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.VacuumTokenTransfersAfterEip7708Sanitizing

  @table_name :token_transfers
  # The name generated for the index, `token_transfers_token_contract_address_hash__block_number_DESC_log_index_DESC_index`,
  # is truncated by PostgreSQL to 63 bytes.
  @index_name "token_transfers_token_contract_address_hash__block_number_DESC_"
  @operation_type :reindex

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      VacuumTokenTransfersAfterEip7708Sanitizing.migration_name()
    ]
end
