defmodule Explorer.Migrator.BackfillMultichainSearchDbCurrentTokenBalances do
  @moduledoc """
  Backfills current token balances from Blockscout DB to Multichain Search DB.

  This migration exports only records from `address_current_token_balances` and
  intentionally does not export coin balances.
  """

  require Logger

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Migrator.FillingMigration

  @migration_name "backfill_multichain_search_db_current_token_balances"
  @failed_to_export_data_error "Batch token-balance export to the Multichain Search DB failed"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def unprocessed_data_query(state) do
    last_processed_id = Map.get(state, "last_processed_id", 0)

    from(ctb in CurrentTokenBalance,
      where: ctb.id > ^last_processed_id,
      where: ctb.block_number >= ^min_block_number(),
      order_by: [asc: ctb.id],
      select: ctb.id
    )
  end

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      state
      |> unprocessed_data_query()
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    new_state =
      case List.last(ids) do
        nil -> state
        id -> Map.put(state, "last_processed_id", id)
      end

    {ids, new_state}
  end

  @impl FillingMigration
  def update_batch(ids) do
    balances =
      from(ctb in CurrentTokenBalance,
        where: ctb.id in ^ids,
        order_by: [asc: ctb.id]
      )
      |> Repo.all(timeout: :infinity)

    to_import = %{
      addresses: [],
      blocks: [],
      transactions: [],
      address_current_token_balances: balances
    }

    case MultichainSearch.batch_import(to_import) do
      {:ok, _} = result ->
        result

      {:error, _} ->
        Logger.error(fn ->
          ["#{@failed_to_export_data_error}", ": ", "#{inspect(ids)}"]
        end)

        :timer.sleep(1000)

        update_batch(ids)
    end
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_backfill_multichain_search_db_current_token_balances_finished(true)
  end

  defp min_block_number do
    Application.get_env(:explorer, __MODULE__)[:min_block_number] || 0
  end
end
