defmodule BlockScoutWeb.GraphQL.Celo.Resolvers.TokenTransfer do
  @moduledoc """
  Resolvers for token transfers, used in the CELO schema.
  """

  alias Absinthe.Relay.Connection
  alias Explorer.GraphQL.Celo, as: GraphQL
  alias Explorer.Repo

  def get_by(_, args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    GraphQL.token_tx_transfers_query()
    |> Connection.from_query(&Repo.all/1, connection_args, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
