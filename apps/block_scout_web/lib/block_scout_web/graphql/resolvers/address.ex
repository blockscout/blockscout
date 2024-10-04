defmodule BlockScoutWeb.GraphQL.Resolvers.Address do
  @moduledoc false

  alias Explorer.Chain

  def get_by(_, %{hashes: hashes}, _) do
    case Chain.hashes_to_addresses(hashes) do
      [] -> {:error, "Addresses not found."}
      result -> {:ok, result}
    end
  end

  def get_by(_, %{hash: hash}, _) do
    case Chain.hash_to_address(hash) do
      {:error, :not_found} -> {:error, "Address not found."}
      {:ok, _} = result -> result
    end
  end
end
