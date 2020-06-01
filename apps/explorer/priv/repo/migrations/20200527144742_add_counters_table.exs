defmodule Explorer.Repo.Migrations.AddCountersTable do
  use Ecto.Migration

  def change do
    create table(:last_fetched_counters, primary_key: false) do
      add(:counter_type, :string, primary_key: true, null: false)
      add(:value, :numeric, precision: 100, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
