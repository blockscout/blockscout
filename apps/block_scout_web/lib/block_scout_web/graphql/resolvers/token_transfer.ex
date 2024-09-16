defmodule BlockScoutWeb.GraphQL.Resolvers.TokenTransfer do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias BlockScoutWeb.GraphQL.Resolvers.Helper
  alias Explorer.Chain.{Address, TokenTransfer}
  alias Explorer.{GraphQL, Repo}

  def get_by(%{transaction_hash: _, log_index: _} = args, resolution) do
    if resolution.context.api_enabled do
      GraphQL.get_token_transfer(args)
    else
      {:error, Helper.api_is_disabled()}
    end
  end

  def get_by(_, %{token_contract_address_hash: token_contract_address_hash} = args, resolution) do
    if resolution.context.api_enabled do
      connection_args = Map.take(args, [:after, :before, :first, :last])

      token_contract_address_hash
      |> GraphQL.list_token_transfers_query()
      |> Connection.from_query(&Repo.replica().all/1, connection_args, options(args))
    else
      {:error, Helper.api_is_disabled()}
    end
  end

  def get_by(%Address{hash: address_hash}, args, resolution) do
    if resolution.context.api_enabled do
      connection_args = Map.take(args, [:after, :before, :first, :last])

      address_hash
      |> TokenTransfer.token_transfers_by_address_hash(nil, [], nil)
      |> Connection.from_query(&Repo.replica().all/1, connection_args, options(args))
    else
      {:error, Helper.api_is_disabled()}
    end
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
