# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateTokensMarketDataPartialIndex do
  @moduledoc """
  Creates partial B-tree index `tokens_market_data_partial_index` on the `tokens` table
  for (`contract_address_hash`), filtered by
  `circulating_market_cap IS NOT NULL OR fiat_value IS NOT NULL`.

  The index is there to find the few tokens which have market data without scanning the
  table, not to order them: there are few enough of them to be sorted on each request of
  the tokens list, see `Explorer.Chain.Token.list_top/2`. The rest of the tokens are
  covered by `tokens_no_market_data_holder_count_name_hash_index`.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateTokensNoMarketDataHolderCountNameHashIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :tokens
  @index_name "tokens_market_data_partial_index"
  @operation_type :create

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
  ON #{@table_name} (contract_address_hash)
  WHERE circulating_market_cap IS NOT NULL OR fiat_value IS NOT NULL;
  """

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [CreateTokensNoMarketDataHolderCountNameHashIndex.migration_name()]
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_tokens_market_data_partial_index_finished(true)
  end
end
