defmodule Explorer.Workers.RefreshBalance do
  @moduledoc """
    Refreshes the Credit and Debit balance views.
  """

  alias Ecto.Adapters.SQL
  alias Explorer.Credit
  alias Explorer.Debit
  alias Explorer.Repo

  def perform("credit"), do: unless(refreshing("credits"), do: Credit.refresh())
  def perform("debit"), do: unless(refreshing("debits"), do: Debit.refresh())

  def perform do
    perform_later(["credit"])
    perform_later(["debit"])
  end

  def perform_later(args \\ []) do
    Exq.enqueue(Exq.Enqueuer, "default", __MODULE__, args)
  end

  def refreshing(table) do
    query = "REFRESH MATERIALIZED VIEW CONCURRENTLY #{table}%"

    result =
      SQL.query!(Repo, "SELECT TRUE FROM pg_stat_activity WHERE query ILIKE '$#{query}'", [])

    Enum.count(result.rows) > 0
  end
end
