# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateTokensNoMarketDataHolderCountNameHashIndex do
  @moduledoc """
  Creates partial B-tree index `tokens_no_market_data_holder_count_name_hash_index` on the
  `tokens` table for (`holder_count DESC NULLS LAST`, `name`, `contract_address_hash`),
  filtered by `circulating_market_cap IS NULL AND fiat_value IS NULL`.

  The tokens list is sorted by the market cap, the fiat value and the holders count, in
  the order the client asks for. Almost all the tokens have neither a market cap nor a
  fiat value, and whatever the requested order is, these tokens go by the holders count,
  the name and the address hash. So this single index gives their part of the list in any
  of the orders, see `Explorer.Chain.Token.list_top/2`. The tokens which do have market
  data are covered by `tokens_market_data_partial_index`.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :tokens
  @index_name "tokens_no_market_data_holder_count_name_hash_index"
  @operation_type :create

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
  ON #{@table_name} (holder_count DESC NULLS LAST, name, contract_address_hash)
  WHERE circulating_market_cap IS NULL AND fiat_value IS NULL;
  """

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_tokens_no_market_data_holder_count_name_hash_index_finished(true)
  end
end
