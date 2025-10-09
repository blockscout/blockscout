defmodule BlockScoutWeb.GraphQL.Celo.Resolvers.TokenTransfer do
  @moduledoc """
  Resolvers for token transfers, used in the CELO schema.
  """

  alias Absinthe.Relay.Connection
  alias Explorer.GraphQL.Celo, as: GraphQL
  alias Explorer.Repo

  def get_by(%{transaction_hash: hash}, args, _) do
    hash
    |> GraphQL.token_transaction_transfers_query_by_transaction_hash()
    |> Connection.from_query(&Repo.all/1, args, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
