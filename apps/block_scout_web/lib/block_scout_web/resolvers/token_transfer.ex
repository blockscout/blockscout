defmodule BlockScoutWeb.Resolvers.TokenTransfer do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{GraphQL, Repo}

  def get_by(%{transaction_hash: _, log_index: _} = args) do
    GraphQL.get_token_transfer(args)
  end

  def get_by(_, %{token_contract_address_hash: token_contract_address_hash} = args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    token_contract_address_hash
    |> GraphQL.list_token_transfers_query()
    |> Connection.from_query(&Repo.all/1, connection_args, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
