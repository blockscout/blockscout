defmodule Explorer.Repo.Migrations.CreateStateBatches do
  use Ecto.Migration

  def change do
    create table(:state_batches, primary_key: false) do
      add(:batch, :bigint, null: false)
      add(:hash, :bytea, null: false, primary_key: true)
      add(:size, :bigint, null: false)
      add(:index, :bigint, null: false)
      add(:pre_total_elements, :numeric, precision: 100)
      add(:timestamp, :utc_datetime_usec, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
