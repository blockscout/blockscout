defmodule Explorer.Migrator.ArbitrumMigrateFromL1Executions do
  @moduledoc """
  Migration to move data from arbitrum_l1_executions to arbitrum_crosslevel_messages.

  This migration creates message records with the `direction`, `message_id`,
  `completion_transaction_hash`, and `status` fields populated in
  `arbitrum_crosslevel_messages` for those records in `arbitrum_l1_executions` for
  which the records in `arbitrum_crosslevel_messages` directed from the rollup do
  not have `completion_transaction_hash` pointed to `arbitrum_lifecycle_l1_transactions`.

  As soon as the migration is finished all the records from `arbitrum_l1_executions`
  are removed.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Arbitrum.{L1Execution, LifecycleTransaction, Message}

  alias Explorer.{
    Chain,
    Migrator.FillingMigration,
    Repo
  }

  alias Explorer.Chain.Cache.BackgroundMigrations

  @impl FillingMigration
  def migration_name, do: "arbitrum_migrate_from_l1_executions"

  @impl FillingMigration
  def unprocessed_data_query do
    # Find L1 executions that don't have corresponding messages with completion_transaction_hash
    # pointing to the execution transaction
    from(ex in L1Execution,
      join: txn in LifecycleTransaction,
      on: ex.execution_id == txn.id,
      left_join: msg in Message,
      on: msg.direction == :from_l2 and msg.message_id == ex.message_id,
      where: is_nil(msg.completion_transaction_hash) or is_nil(msg.message_id),
      select: %{
        message_id: ex.message_id,
        execution_transaction_hash: txn.hash
      }
    )
  end

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    identifiers =
      unprocessed_data_query()
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {identifiers, state}
  end

  @impl FillingMigration
  def update_batch(identifiers) do
    messages =
      Enum.map(identifiers, fn %{message_id: message_id, execution_transaction_hash: execution_transaction_hash} ->
        %{
          direction: :from_l2,
          message_id: message_id,
          completion_transaction_hash: execution_transaction_hash,
          status: :relayed
        }
      end)

    # Import messages in a transaction to ensure atomicity
    Repo.transaction(fn ->
      # Import messages
      {:ok, _} =
        Chain.import(%{
          arbitrum_messages: %{params: messages},
          timeout: :infinity
        })

      # Delete processed executions
      message_ids = Enum.map(identifiers, & &1.message_id)

      query =
        from(ex in L1Execution,
          where: ex.message_id in ^message_ids
        )

      Repo.delete_all(query, timeout: :infinity)
    end)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_arbitrum_migrate_from_l1_executions_finished(true)
  end

  @impl FillingMigration
  def on_finish do
    # Delete any remaining executions that might have been processed by other means
    # (e.g. by the block fetcher or the catchup process)
    query =
      from(ex in L1Execution)

    Repo.delete_all(query, timeout: :infinity)

    :ok
  end
end
