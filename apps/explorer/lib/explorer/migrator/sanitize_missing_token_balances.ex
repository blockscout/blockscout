defmodule Explorer.Migrator.SanitizeMissingTokenBalances do
  @moduledoc """
  Deletes empty current token balances if the related highest block_number historical token balance is filled.
  Set value and value_fetched_at to nil for those token balances so the token balance fetcher could re-fetch them.
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
      |> select([ctb, tb], {ctb.id, tb.id})
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
          ((is_nil(ctb.token_id) and is_nil(tb.token_id)) or ctb.token_id == tb.token_id),
      where: is_nil(ctb.value) or is_nil(ctb.value_fetched_at),
      where: not is_nil(tb.value) and not is_nil(tb.value_fetched_at),
      distinct: ctb.id,
      order_by: [asc: ctb.id, desc: tb.block_number]
    )
  end

  @impl FillingMigration
  def update_batch(identifiers) do
    {ctb_ids, tb_ids} =
      Enum.reduce(identifiers, {[], []}, fn {ctb_id, tb_id}, {ctb_acc, tb_acc} ->
        {[ctb_id | ctb_acc], [tb_id | tb_acc]}
      end)

    Repo.transaction(fn ->
      ctb_query = from(ctb in CurrentTokenBalance, where: ctb.id in ^ctb_ids)

      Repo.delete_all(ctb_query, timeout: :infinity)

      tb_query =
        from(tb in TokenBalance,
          where: tb.id in ^tb_ids,
          update: [set: [value: nil, value_fetched_at: nil]]
        )

      Repo.update_all(tb_query, [], timeout: :infinity)
    end)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
