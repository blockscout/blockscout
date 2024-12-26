defmodule Explorer.Migrator.AddressCurrentTokenBalanceTokenType do
  @moduledoc """
  Fill empty token_type's for address_current_token_balances
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "ctb_token_type"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([ctb], ctb.id)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(ctb in CurrentTokenBalance, where: is_nil(ctb.token_type))
  end

  @impl FillingMigration
  def update_batch(token_balance_ids) do
    query =
      from(current_token_balance in CurrentTokenBalance,
        join: token in assoc(current_token_balance, :token),
        where: current_token_balance.id in ^token_balance_ids,
        update: [set: [token_type: token.type]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_ctb_token_type_finished(true)
  end
end
