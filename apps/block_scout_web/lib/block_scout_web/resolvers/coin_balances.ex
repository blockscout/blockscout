defmodule BlockScoutWeb.Resolvers.CoinBalances do

  alias Absinthe.Relay.Connection
  alias Explorer.{GraphQL, Repo}

  def get_by(_, %{address: address_hash} = args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    address_hash
    |> GraphQL.list_coin_balances_query()
    |> Connection.from_query(&Repo.all/1, connection_args, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
