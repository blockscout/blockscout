defmodule BlockScoutWeb.GraphQL.Resolvers.Transaction do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias BlockScoutWeb.GraphQL.Resolvers.Helper
  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.Address

  def get_by(_, %{hash: hash}, resolution) do
    with {:api_enabled, true} <- {:api_enabled, resolution.context.api_enabled},
         {:ok, transaction} <- Chain.hash_to_transaction(hash) do
      {:ok, transaction}
    else
      {:api_enabled, false} -> {:error, Helper.api_is_disabled()}
      {:error, :not_found} -> {:error, "Transaction not found."}
    end
  end

  def get_by(%Address{hash: address_hash}, args, resolution) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    if resolution.context.api_enabled do
      address_hash
      |> GraphQL.address_to_transactions_query(args.order)
      |> Connection.from_query(&Repo.all/1, connection_args, options(args))
    else
      {:error, Helper.api_is_disabled()}
    end
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
