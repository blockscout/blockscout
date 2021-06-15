defmodule BlockScoutWeb.Resolvers.CeloClaim do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.CeloAccount

  def get_by(_, %{hash: hash}, _) do
    {:ok, Chain.get_celo_claims(hash)}
  end

  def get_by(%CeloAccount{address: hash}, args, _) do
    hash
    |> GraphQL.address_to_claims_query()
    |> Connection.from_query(&Repo.all/1, args, [])
  end
end
