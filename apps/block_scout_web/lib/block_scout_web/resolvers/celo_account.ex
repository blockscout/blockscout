defmodule BlockScoutWeb.Resolvers.CeloAccount do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.Address

  def get_by(_, %{hash: hash}, _) do
    case Chain.get_celo_account(hash) do
      {:error, :not_found} -> {:error, "Celo account not found."}
      {:ok, _} = result -> result
    end
  end

  def get_by(%Address{hash: hash}, args, _) do
    hash
    |> GraphQL.address_to_account_query()
    |> Connection.from_query(&Repo.all/1, args, [])
  end
end
