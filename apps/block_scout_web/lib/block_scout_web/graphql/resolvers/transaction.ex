defmodule BlockScoutWeb.GraphQL.Resolvers.Transaction do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{GraphQL, Repo}
  alias Explorer.Chain.{Address, TokenTransfer}

  def get_by(_, %{hash: hash}, _),
    do: GraphQL.get_transaction_by_hash(hash)

  def get_by(%Address{hash: address_hash}, args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    address_hash
    |> GraphQL.address_to_transactions_query(args.order)
    |> Connection.from_query(&Repo.replica().all/1, connection_args, options(args))
  end

  def get_by(%TokenTransfer{transaction_hash: hash}, _, _),
    do: GraphQL.get_transaction_by_hash(hash)

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
