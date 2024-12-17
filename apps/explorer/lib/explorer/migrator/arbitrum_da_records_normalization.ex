defmodule Explorer.Migrator.ArbitrumDaRecordsNormalization do
  @moduledoc """
  Normalizes batch-to-blob associations by moving them from arbitrum_da_multi_purpose to a dedicated
  arbitrum_batches_to_da_blobs table, establishing proper one-to-many relationships between batches
  and data blobs.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Arbitrum.{BatchToDaBlob, DaMultiPurposeRecord}
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "arbitrum_da_records_normalization"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    data_keys =
      unprocessed_data_query()
      |> select([rec], {rec.data_key, rec.batch_number})
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {data_keys, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    # Finds batch-to-blob associations in arbitrum_da_multi_purpose that haven't been migrated yet
    # to arbitrum_batches_to_da_blobs. Only considers records that have batch_number set.
    from(rec in DaMultiPurposeRecord,
      left_join: btd in BatchToDaBlob,
      on: rec.data_key == btd.data_blob_id,
      where: not is_nil(rec.batch_number) and is_nil(btd.batch_number)
    )
  end

  @impl FillingMigration
  def update_batch(data_keys) do
    records =
      Enum.map(data_keys, fn {data_key, batch_number} ->
        %{
          batch_number: batch_number,
          data_blob_id: data_key,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)

    Repo.insert_all(BatchToDaBlob, records, timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_arbitrum_da_records_normalization_finished(true)
  end
end
