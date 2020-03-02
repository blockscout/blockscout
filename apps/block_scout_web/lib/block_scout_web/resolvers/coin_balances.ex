defmodule BlockScoutWeb.Resolvers.CoinBalances do
  #  import BlockScoutWeb.Chain, only: [paging_options: 1]

  #  alias Explorer.Chain

  alias Absinthe.Relay.Connection
  alias Explorer.{GraphQL, Repo}

  _ = """
    def get_by(_, %{address: address_hash} = args, _) do
      full_options = paging_options(args)
      {:ok, Chain.address_to_coin_balances(address_hash, full_options)}
    end
  """

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
