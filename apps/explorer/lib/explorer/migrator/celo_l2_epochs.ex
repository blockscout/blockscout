defmodule Explorer.Migrator.CeloL2Epochs do
  @moduledoc """
  Backfills Celo L2 epochs data. It processes logs related to epoch processing
  and fills the `Epoch` table with the relevant data.
  """

  use Explorer.Migrator.FillingMigration

  use Utils.RuntimeEnvHelper,
    epoch_manager_contract_address_hash: [
      :explorer,
      [:celo, :epoch_manager_contract_address]
    ]

  import Ecto.Query

  alias Explorer.Chain.Celo.Epoch
  alias Explorer.{Helper, Repo}
  alias Explorer.Chain.{Import, Log}
  alias Explorer.Chain.Import.Runner.Celo.Epochs
  alias Explorer.Migrator.FillingMigration

  @migration_name "celo_l2_epochs"

  # Events from the EpochManager contract
  @epoch_processing_started_topic "0xae58a33f8b8d696bcbaca9fa29d9fdc336c140e982196c2580db3d46f3e6d4b6"
  @epoch_processing_ended_topic "0xc8e58d8e6979dd5e68bad79d4a4368a1091f6feb2323e612539b1b84e0663a8f"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([log], log)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    epochs_start_processing_block_hashes =
      from(epoch in Epoch, select: epoch.start_processing_block_hash)

    epochs_end_processing_block_hashes =
      from(epoch in Epoch, select: epoch.end_processing_block_hash)

    from(
      log in Log,
      where:
        log.address_hash == ^epoch_manager_contract_address_hash() and
          ((log.first_topic == ^@epoch_processing_started_topic and
              log.block_hash not in subquery(epochs_start_processing_block_hashes)) or
             (log.first_topic == ^@epoch_processing_ended_topic and
                log.block_hash not in subquery(epochs_end_processing_block_hashes))),
      order_by: [asc: log.block_number]
    )
  end

  @impl FillingMigration
  def update_batch(logs) do
    changes_list =
      logs
      |> Enum.reduce(%{}, fn log, epochs_acc ->
        # Extract epoch number from the log
        [epoch_number] = log.second_topic |> to_string() |> Helper.decode_data([{:uint, 256}])

        current_epoch = Map.get(epochs_acc, epoch_number, %{number: epoch_number})

        updated_epoch =
          log.first_topic
          |> to_string()
          |> case do
            @epoch_processing_started_topic ->
              Map.put(current_epoch, :start_processing_block_hash, log.block_hash)

            @epoch_processing_ended_topic ->
              Map.put(current_epoch, :end_processing_block_hash, log.block_hash)
          end

        Map.put(epochs_acc, epoch_number, updated_epoch)
      end)
      |> Map.values()

    Epochs.insert(
      Repo,
      changes_list,
      %{
        timeout: :infinity,
        timestamps: Import.timestamps()
      }
    )
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
