defmodule BlockScoutWeb.Resolvers.CeloTransfer do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{GraphQL, Repo}

  def get_by(%{transaction_hash: hash}, args, _) do
    hash
    |> GraphQL.celo_tx_transfers_query_by_txhash()
    |> Connection.from_query(&Repo.all/1, args, options(args))
  end

  def get_by(_, %{address_hash: address_hash} = args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    address_hash
    |> GraphQL.celo_tx_transfers_query_by_address()
    |> Connection.from_query(&Repo.all/1, connection_args, options(args))
  end

  def get_by(_, args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    GraphQL.celo_tx_transfers_query()
    |> Connection.from_query(&Repo.all/1, connection_args, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
