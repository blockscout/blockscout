defmodule BlockScoutWeb.Resolvers.CeloValidator do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.{Address, CeloValidatorGroup}

  def get_by(_, %{hash: hash}, _) do
    case Chain.get_celo_validator(hash) do
      {:error, :not_found} -> {:error, "Celo validator not found."}
      {:ok, _} = result -> result
    end
  end

  def get_by(%Address{hash: hash}, args, _) do
    hash
    |> GraphQL.address_to_validator_query()
    |> Connection.from_query(&Repo.all/1, args, [])
  end

  def get_by(%CeloValidatorGroup{address: hash}, args, _) do
    hash
    |> GraphQL.address_to_affiliates_query()
    |> Connection.from_query(&Repo.all/1, args, [])
  end
end
