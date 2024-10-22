defmodule Explorer.Repo.Scroll.Migrations.AddBatchesTables do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE scroll_da_containers_types AS ENUM ('in_blob4844', 'in_calldata')",
      "DROP TYPE scroll_da_containers_types"
    )

    create table(:scroll_batch_bundles, primary_key: true) do
      add(:final_batch_number, :bigint, null: false)
      add(:finalize_transaction_hash, :bytea, null: false)
      add(:finalize_block_number, :bigint, null: false)
      add(:finalize_timestamp, :"timestamp without time zone", null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create table(:scroll_batches, primary_key: false) do
      add(:number, :bigint, primary_key: true)
      add(:commit_transaction_hash, :bytea, null: false)
      add(:commit_block_number, :bigint, null: false)
      add(:commit_timestamp, :"timestamp without time zone", null: false)

      add(
        :bundle_id,
        references(:scroll_batch_bundles, on_delete: :restrict, on_update: :update_all, type: :bigint),
        null: true,
        default: nil
      )

      add(:l2_block_range, :int8range)
      add(:container, :scroll_da_containers_types, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:scroll_batch_bundles, :finalize_block_number))
    create(index(:scroll_batches, :commit_block_number))
    create(index(:scroll_batches, :l2_block_range))
  end
end
