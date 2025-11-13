defmodule Explorer.Migrator.CeloAggregatedElectionRewards do
  @moduledoc """
  Backfills the `celo_aggregated_election_rewards` table with aggregated
  statistics from the `celo_election_rewards` table for all finalized epochs.

  This migration calculates the sum and count of rewards grouped by epoch number
  and reward type, creating pre-computed aggregates that significantly improve
  query performance for epoch reward statistics.

  Only epochs with at least one election reward are processed. Epochs with zero
  rewards are skipped.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Celo.{AggregatedElectionReward, ElectionReward, Epoch}
  alias Explorer.Migrator.FillingMigration

  @migration_name "celo_aggregated_election_rewards"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    epoch_numbers =
      unprocessed_data_query()
      |> select([e], e.number)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {epoch_numbers, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    # Get all epochs that have been finalized (have end_processing_block_hash)
    # but don't yet have aggregated election rewards.
    # Only process epochs that have at least one election reward to avoid
    # reprocessing epochs with no rewards indefinitely.
    aggregated_epoch_numbers =
      from(aer in AggregatedElectionReward,
        select: aer.epoch_number,
        distinct: true
      )

    epochs_with_rewards =
      from(er in ElectionReward,
        select: er.epoch_number,
        distinct: true
      )

    from(
      e in Epoch,
      join: r in subquery(epochs_with_rewards),
      on: r.epoch_number == e.number,
      where: not is_nil(e.end_processing_block_hash),
      where: e.number not in subquery(aggregated_epoch_numbers),
      order_by: [asc: e.number]
    )
  end

  @impl FillingMigration
  def update_batch(epoch_numbers) when is_list(epoch_numbers) do
    query =
      from(
        er in ElectionReward,
        where: er.epoch_number in ^epoch_numbers,
        group_by: [er.epoch_number, er.type],
        select: %{
          epoch_number: er.epoch_number,
          type: er.type,
          sum: sum(er.amount),
          count: count(er.amount)
        }
      )

    aggregates = Repo.all(query, timeout: :infinity)

    Chain.import(%{
      celo_aggregated_election_rewards: %{
        params: aggregates
      }
    })
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
