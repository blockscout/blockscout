defmodule BlockScoutWeb.Resolvers.CeloValidatorGroup do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.{Address, CeloValidator}

  def get_by(_, %{hash: hash}, _) do
    case Chain.get_celo_validator_group(hash) do
      {:error, :not_found} -> {:error, "Celo validator group not found."}
      {:ok, _} = result -> result
    end
  end

  def get_by(%Address{hash: hash}, args, _) do
    hash
    |> GraphQL.address_to_validator_group_query()
    |> Connection.from_query(&Repo.all/1, args, [])
  end

  def get_by(%CeloValidator{group_address_hash: hash}, args, _) do
    hash
    |> GraphQL.address_to_validator_group_query()
    |> Connection.from_query(&Repo.all/1, args, [])
  end

  def get_by(_, _, _) do
    case Chain.get_celo_validator_groups() do
      {:error, :not_found} -> {:error, "Celo validator group query failed."}
      {:ok, _} = result -> result
    end
  end
end
