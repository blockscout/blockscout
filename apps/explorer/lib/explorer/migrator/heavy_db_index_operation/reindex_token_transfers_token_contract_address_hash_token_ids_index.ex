# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex do
  @moduledoc """
  Rebuilds index "token_transfers_token_contract_address_hash_token_ids_index" gin
  (token_contract_address_hash, token_ids).

  The rebuild reclaims the space taken in the index by the token transfers deleted by
  `Explorer.Migrator.SanitizeEip7708TokenTransfers`, see
  `Explorer.Migrator.HeavyDbIndexOperation.VacuumTokenTransfersAfterEip7708Sanitizing`
  for the details.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation.ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex

  @table_name :token_transfers
  @index_name "token_transfers_token_contract_address_hash_token_ids_index"
  @operation_type :reindex

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex.migration_name()
    ]
end
