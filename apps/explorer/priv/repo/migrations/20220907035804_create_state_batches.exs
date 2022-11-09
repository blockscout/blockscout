defmodule Explorer.Repo.Migrations.CreateStateBatches do
  use Ecto.Migration

  def change do
    create table(:state_batches, primary_key: false) do
      add(:batch_index, :bigint, null: false)
      add(:block_number, :bigint, null: false)
      add(:hash, :bytea, null: false, primary_key: true)
      add(:size, :bigint, null: false)
      #add(:index, :bigint, null: false)
      add(:l1_block_number, :numeric)
      add(:batch_root, :bytea)
      add(:extra_data, :bytea)
      add(:pre_total_elements, :numeric, precision: 100)
      add(:timestamp, :utc_datetime_usec, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
    create(unique_index(:state_batches, [:batch_index]))
  end
end
