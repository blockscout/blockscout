defmodule Explorer.Repo.Arbitrum.Migrations.AddDataBlobsToBatchesTable do
  use Ecto.Migration

  def change do
    create table(:arbitrum_batches_to_da_blobs, primary_key: false) do
      add(
        :batch_number,
        references(:arbitrum_l1_batches,
          column: :number,
          on_delete: :delete_all,
          on_update: :update_all,
          type: :integer
        ),
        null: false,
        primary_key: true
      )

      add(
        :data_blob_id,
        references(:arbitrum_da_multi_purpose,
          column: :data_key,
          on_delete: :delete_all,
          on_update: :update_all,
          type: :bytea
        ),
        null: false
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end

    # Create index for efficient lookups by data_blob_id
    create(index(:arbitrum_batches_to_da_blobs, [:data_blob_id]))
  end
end
