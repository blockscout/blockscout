defmodule Explorer.Repo.Migrations.AddAddressHashIndexToDecompiledSmartContracts do
  use Ecto.Migration

  def change do
    execute(
      """
      CREATE INDEX IF NOT EXISTS decompiled_smart_contracts_address_hash_index ON decompiled_smart_contracts(address_hash);
      """,
      """
      DROP INDEX IF EXISTS decompiled_smart_contracts_address_hash_index
      """
    )
  end
end
