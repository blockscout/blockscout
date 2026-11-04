# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateAddressCurrentTokenBalancesTokenHoldersIndex do
  @moduledoc """
  Create partial B-tree index on `address_current_token_balances` table for the
  token holders queries: `(token_contract_address_hash, value DESC, address_hash DESC)`
  filtered by `address_hash != burn address AND (value > 0 OR token_type = 'ERC-7984')`.

  Replaces "address_current_token_balances_token_contract_address_hash__val"
  (same columns, but predicate `value > 0` only; the name may differ on
  instances where the index was created manually): after the
  `OR token_type = 'ERC-7984'` disjunct was added to the token holders queries
  for confidential tokens support, their predicate stopped implying the old
  index's predicate, making the old partial index unusable for them and forcing
  a sorted scan over a non-partial fallback index. The predicate here matches
  the queries verbatim, and queries filtering by plain `value > 0` can use it
  as well (`value > 0` implies the disjunction).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :address_current_token_balances
  @index_name "address_current_token_balances_token_holders_index"
  @operation_type :create

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
  ON #{@table_name} (token_contract_address_hash, value DESC, address_hash DESC)
  WHERE address_hash != '\\x0000000000000000000000000000000000000000' AND (value > 0 OR token_type = 'ERC-7984');
  """
end
