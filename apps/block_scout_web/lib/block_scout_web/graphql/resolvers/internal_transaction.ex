defmodule BlockScoutWeb.GraphQL.Resolvers.InternalTransaction do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias BlockScoutWeb.GraphQL.Resolvers.Helper
  alias Explorer.Chain.Transaction
  alias Explorer.{GraphQL, Repo}

  def get_by(%{transaction_hash: _, index: _} = args, resolution) do
    if resolution.context.api_enabled do
      GraphQL.get_internal_transaction(args)
    else
      {:error, Helper.api_is_disabled()}
    end
  end

  def get_by(%Transaction{} = transaction, args, resolution) do
    if resolution.context.api_enabled do
      transaction
      |> GraphQL.transaction_to_internal_transactions_query()
      |> Connection.from_query(&Repo.all/1, args, options(args))
    else
      {:error, Helper.api_is_disabled()}
    end
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
