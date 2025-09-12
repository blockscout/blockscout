defmodule Explorer.Repo.Migrations.AddMultichainSearchDbCountersExportQueueTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE multichain_search_counter_type AS ENUM ('global')",
      "DROP TYPE multichain_search_counter_type"
    )

    create table(:multichain_search_db_export_counters_queue, primary_key: false) do
      add(:timestamp, :utc_datetime_usec, primary_key: true)
      add(:counter_type, :multichain_search_counter_type, null: false, primary_key: true)
      add(:data, :jsonb, null: false)
      add(:retries_number, :smallint, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
