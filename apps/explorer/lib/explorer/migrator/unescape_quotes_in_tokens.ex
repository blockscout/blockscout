defmodule Explorer.Migrator.UnescapeQuotesInTokens do
  @moduledoc """
  Unescapes single and double quotes in `name` and `symbol` token fields
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Token
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "unescape_quotes_in_tokens"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([t], t.contract_address_hash)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    where(Token, [t], fragment("? ~ E'(&#39;|&quot;)' or ? ~ E'(&#39;|&quot;)'", t.name, t.symbol))
  end

  @impl FillingMigration
  def update_batch(contract_address_hashes) do
    params =
      Token
      |> where([t], t.contract_address_hash in ^contract_address_hashes)
      |> Repo.all()
      |> Enum.map(fn token ->
        %{
          contract_address_hash: token.contract_address_hash,
          name: do_unescape(token.name),
          symbol: do_unescape(token.symbol),
          type: token.type,
          inserted_at: token.inserted_at,
          updated_at: token.updated_at
        }
      end)

    Repo.insert_all(Token, params, on_conflict: {:replace, [:name, :symbol]}, conflict_target: :contract_address_hash)
  end

  @impl FillingMigration
  def update_cache, do: :ok

  defp do_unescape(nil), do: nil

  defp do_unescape(string) do
    string
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
  end
end
