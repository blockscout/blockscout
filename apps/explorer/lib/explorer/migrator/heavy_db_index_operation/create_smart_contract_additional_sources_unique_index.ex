# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateSmartContractAdditionalSourcesUniqueIndex do
  @moduledoc """
  Creates a unique index on the smart_contract_additional_sources table.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{HeavyDbIndexOperation, SanitizeDuplicateSmartContractAdditionalSources}

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :smart_contracts_additional_sources
  @index_name "smart_contracts_additional_sources_file_name_address_hash_index"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [SanitizeDuplicateSmartContractAdditionalSources.migration_name()]

  @query_string """
  CREATE UNIQUE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
   ON #{@table_name} (address_hash, file_name);
  """
end
