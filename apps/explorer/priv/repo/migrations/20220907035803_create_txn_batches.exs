defmodule Explorer.Repo.Migrations.CreateTxnBatches do
  use Ecto.Migration

  def change do
    create table(:txn_batches, primary_key: false) do
<<<<<<< HEAD
      add(:batch_index, :bigint, null: false)
=======
      add(:batch, :bigint, null: false)
>>>>>>> origin/develop
      add(:hash, :bytea, null: false, primary_key: true)
      add(:size, :bigint, null: false)
      #add(:index, :bigint, null: false)
      add(:pre_total_elements, :numeric, precision: 100)
      add(:timestamp, :utc_datetime_usec, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
    create(unique_index(:txn_batches, [:batch_index]))
  end
end
