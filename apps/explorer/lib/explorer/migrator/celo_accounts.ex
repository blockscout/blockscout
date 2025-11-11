defmodule Explorer.Migrator.CeloAccounts do
  @moduledoc """
  Backfills pending account operations table for each address that has
  Celo-specific events, indicating that their Celo account information needs to
  be fetched and updated.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Celo.{Account, PendingAccountOperation}
  alias Explorer.Chain.Celo.Legacy.{Accounts, Events}
  alias Explorer.Chain.Log
  alias Explorer.Migrator.FillingMigration

  @migration_name "celo_accounts"

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
    pending_op_hashes_query = from(op in PendingAccountOperation, select: op.address_hash)
    existing_account_hashes_query = from(a in Account, select: a.address_hash)
    excluded_hashes_query = pending_op_hashes_query |> union(^existing_account_hashes_query)

    from(
      log in Log,
      where:
        log.first_topic in ^Events.account_events() and
          fragment("SUBSTRING(? from 13)", log.second_topic) not in subquery(excluded_hashes_query),
      order_by: [asc: log.block_number, asc: log.index]
    )
  end

  @impl FillingMigration
  def update_batch(logs) do
    %{accounts: pending_operation_params} = Accounts.parse(logs)

    unique_pending_operation_params = Enum.uniq_by(pending_operation_params, & &1.address_hash)
    address_params = Enum.map(unique_pending_operation_params, &%{hash: &1.address_hash})

    Chain.import(%{
      addresses: %{params: address_params},
      celo_pending_account_operations: %{
        params: unique_pending_operation_params
      }
    })
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
