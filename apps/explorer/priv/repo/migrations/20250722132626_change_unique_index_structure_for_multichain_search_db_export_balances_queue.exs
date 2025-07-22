defmodule Explorer.Repo.Migrations.ChangeUniqueIndexStructureForMultichainSearchDbExportBalancesQueue do
  use Ecto.Migration

  def up do
    drop_if_exists(
      unique_index(
        :multichain_search_db_export_balances_queue,
        [:address_hash, :token_contract_address_hash_or_native, "COALESCE(token_id, -1)"],
        name: :unique_multichain_search_db_current_token_balances
      )
    )

    create_if_not_exists(
      unique_index(
        :multichain_search_db_export_balances_queue,
        [:address_hash, :token_contract_address_hash_or_native, "COALESCE(token_id::numeric, -1::numeric)"],
        name: :unique_multichain_search_db_current_token_balances
      )
    )
  end

  def down do
    drop_if_exists(
      unique_index(
        :multichain_search_db_export_balances_queue,
        [:address_hash, :token_contract_address_hash_or_native, "COALESCE(token_id::numeric, -1::numeric)"],
        name: :unique_multichain_search_db_current_token_balances
      )
    )

    create_if_not_exists(
      unique_index(
        :multichain_search_db_export_balances_queue,
        [:address_hash, :token_contract_address_hash_or_native, "COALESCE(token_id, -1)"],
        name: :unique_multichain_search_db_current_token_balances
      )
    )
  end
end
