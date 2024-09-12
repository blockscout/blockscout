defmodule Explorer.Migrator.SanitizeMissingTokenBalances do
  @moduledoc """
  Set value and value_fetched_at to nil for those token balances that are already filled but their
  current token balances are not so the token balance fetcher could re-fetch them.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Address.{CurrentTokenBalance, TokenBalance}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "sanitize_missing_token_balances"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([_ctb, tb], tb.id)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(
      ctb in CurrentTokenBalance,
      join: tb in TokenBalance,
      on:
        ctb.address_hash == tb.address_hash and
          ctb.token_contract_address_hash == tb.token_contract_address_hash and
          ctb.block_number == tb.block_number and
          ((is_nil(ctb.token_id) and is_nil(tb.token_id)) or ctb.token_id == tb.token_id),
      where: is_nil(ctb.value) or is_nil(ctb.value_fetched_at),
      where: not is_nil(tb.value) and not is_nil(tb.value_fetched_at)
    )
  end

  @impl FillingMigration
  def update_batch(token_balance_ids) do
    query =
      from(tb in TokenBalance,
        where: tb.id in ^token_balance_ids,
        update: [set: [value: nil, value_fetched_at: nil]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
