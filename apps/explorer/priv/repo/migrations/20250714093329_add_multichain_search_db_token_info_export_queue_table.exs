defmodule Explorer.Repo.Migrations.AddMultichainSearchDbTokenInfoExportQueueTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE multichain_search_token_data_type AS ENUM ('metadata', 'total_supply', 'counters', 'market_data')",
      "DROP TYPE multichain_search_token_data_type"
    )

    create table(:multichain_search_db_export_token_info_queue, primary_key: false) do
      add(:address_hash, :bytea, null: false, primary_key: true)
      add(:data_type, :multichain_search_token_data_type, null: false, primary_key: true)
      add(:data, :jsonb, null: false)
      add(:retries_number, :smallint, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    alter table(:tokens) do
      add(:transfer_count, :integer, null: true)
    end
  end
end
