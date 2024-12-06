defmodule BlockScoutWeb.GraphQL.Celo.Resolvers.TokenTransferTransaction do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.GraphQL.Celo, as: GraphQL
  alias Explorer.Repo

  def get_by(_, %{address_hash: address_hash, first: limit} = args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    offset =
      case Connection.offset(args) do
        {:ok, offset} when is_integer(offset) -> offset
        _ -> 0
      end

    address_hash
    |> GraphQL.token_transaction_transfers_query_for_address(offset, limit)
    |> Connection.from_query(&Repo.all/1, connection_args, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
