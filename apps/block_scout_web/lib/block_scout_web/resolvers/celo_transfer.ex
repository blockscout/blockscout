defmodule BlockScoutWeb.Resolvers.CeloTransfer do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{GraphQL, Repo}

  def get_by(%{transaction_hash: hash}, args, _) do
    hash
    |> GraphQL.celo_tx_transfers_query_by_txhash()
    |> Connection.from_query(&Repo.all/1, args, options(args))
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
