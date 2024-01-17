defmodule Explorer.Repo.Beacon.Migrations.CreateBlobsTables do
  use Ecto.Migration

  def change do
    create table(:beacon_blobs_transactions, primary_key: false) do
      add(:hash, references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false,
        primary_key: true
      )

      add(:max_fee_per_blob_gas, :numeric, precision: 100, null: false)
      add(:blob_gas_price, :numeric, precision: 100, null: false)
      add(:blob_gas_used, :numeric, precision: 100, null: false)
      add(:blob_versioned_hashes, {:array, :bytea}, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    alter table(:blocks) do
      add(:blob_gas_used, :numeric, precision: 100)
      add(:excess_blob_gas, :numeric, precision: 100)
    end

    create table(:beacon_blobs, primary_key: false) do
      add(:hash, :bytea, null: false, primary_key: true)

      add(:blob_data, :bytea, null: true)
      add(:kzg_commitment, :bytea, null: true)
      add(:kzg_proof, :bytea, null: true)

      timestamps(updated_at: false, null: false, type: :utc_datetime_usec, default: fragment("now()"))
    end
  end
end
