defmodule BlockScoutWeb.Resolvers.Transaction do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.Address

  def get_by(_, %{hash: hash}, _) do
    case Chain.hash_to_transaction(hash) do
      {:ok, transaction} -> {:ok, transaction}
      {:error, :not_found} -> {:error, "Transaction not found."}
    end
  end

  def get_by(%Address{hash: address_hash}, args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    address_hash
    |> GraphQL.address_to_transactions_query(args.order)
    |> Connection.from_query(&Repo.all/1, connection_args, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
