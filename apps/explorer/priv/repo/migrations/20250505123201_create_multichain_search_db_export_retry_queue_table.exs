defmodule Explorer.Repo.Migrations.CreateMultichainSearchDbExportRetryQueueTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE multichain_search_hash_type AS ENUM ('block', 'transaction', 'address')",
      "DROP TYPE multichain_search_hash_type"
    )

    create table(:multichain_search_db_export_retry_queue, primary_key: false) do
      add(:hash, :bytea, null: false, primary_key: true)
      add(:hash_type, :multichain_search_hash_type, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
