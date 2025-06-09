defmodule Explorer.Repo.Migrations.AddMultichainSearchDbBalancesExportQueueTable do
  use Ecto.Migration

  def change do
    create table(:multichain_search_db_export_balances_queue, primary_key: false) do
      add(:id, :serial, null: false, primary_key: true)
      add(:address_hash, :bytea, null: false)
      add(:token_contract_address_hash_or_native, :bytea, null: false)
      add(:value, :numeric, precision: 100, scale: 0, null: true)
      add(:token_id, :numeric, precision: 78, scale: 0, null: true)
      add(:retries_number, :smallint, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create_if_not_exists(
      unique_index(
        :multichain_search_db_export_balances_queue,
        [:address_hash, :token_contract_address_hash_or_native, "COALESCE(token_id, -1)"],
        name: :unique_multichain_search_db_current_token_balances
      )
    )
  end
end
