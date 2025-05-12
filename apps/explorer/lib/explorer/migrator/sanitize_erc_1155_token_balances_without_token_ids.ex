defmodule Explorer.Migrator.SanitizeErc1155TokenBalancesWithoutTokenIds do
  @moduledoc """
  Deletes token balances of ERC-1155 tokens with empty token_id.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "sanitize_erc_1155_token_balances_without_token_ids"

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
    from(
      tb in TokenBalance,
      join: t in assoc(tb, :token),
      where: tb.token_type == ^"ERC-1155" and t.type == ^"ERC-1155" and is_nil(tb.token_id)
    )
  end

  @impl FillingMigration
  def update_batch(token_balance_ids) do
    query = from(tb in TokenBalance, where: tb.id in ^token_balance_ids)

    Repo.delete_all(query, timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
