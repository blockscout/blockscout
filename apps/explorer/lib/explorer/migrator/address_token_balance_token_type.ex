defmodule Explorer.Migrator.AddressTokenBalanceTokenType do
  @moduledoc """
  Fill empty token_type's for address_token_balances
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "tb_token_type"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([tb], tb.id)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(tb in TokenBalance, where: is_nil(tb.token_type))
  end

  @impl FillingMigration
  def update_batch(token_balance_ids) do
    query =
      from(token_balance in TokenBalance,
        join: token in assoc(token_balance, :token),
        where: token_balance.id in ^token_balance_ids,
        update: [set: [token_type: token.type]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_tb_token_type_finished(true)
  end
end
