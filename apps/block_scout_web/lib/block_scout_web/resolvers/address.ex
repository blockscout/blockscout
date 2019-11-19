defmodule BlockScoutWeb.Resolvers.Address do
  @moduledoc false

  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.CeloAccount
  alias Absinthe.Relay.Connection

  def get_by(_, %{hashes: hashes}, _) do
    case Chain.hashes_to_addresses(hashes) do
      [] -> {:error, "Addresses not found."}
      result -> {:ok, result}
    end
  end

  def get_by(_, %{hash: hash}, _) do
    case Chain.hash_to_address(hash) do
      {:error, :not_found} ->
        {:error, "Address not found."}

      {:ok, _} = result ->
        IO.inspect(result)
        result
    end
  end

  def get_by(%CeloAccount{address: hash}, args, _) do
    hash
    |> GraphQL.address_query()
    |> Connection.from_query(&Repo.all/1, args, [])
  end
end
