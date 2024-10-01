defmodule BlockScoutWeb.GraphQL.Resolvers.InternalTransaction do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.Chain.Transaction
  alias Explorer.{GraphQL, Repo}

  def get_by(%{transaction_hash: _, index: _} = args, _) do
    GraphQL.get_internal_transaction(args)
  end

  def get_by(%Transaction{} = transaction, args, _) do
    transaction
    |> GraphQL.transaction_to_internal_transactions_query()
    |> Connection.from_query(&Repo.all/1, args, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
