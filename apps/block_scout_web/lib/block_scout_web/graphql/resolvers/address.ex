defmodule BlockScoutWeb.GraphQL.Resolvers.Address do
  @moduledoc false

  alias BlockScoutWeb.GraphQL.Resolvers.Helper
  alias Explorer.Chain

  def get_by(_, %{hashes: hashes}, resolution) do
    if resolution.context.api_enabled do
      case Chain.hashes_to_addresses(hashes) do
        [] -> {:error, "Addresses not found."}
        result -> {:ok, result}
      end
    else
      {:error, Helper.api_is_disabled()}
    end
  end

  def get_by(_, %{hash: hash}, resolution) do
    if resolution.context.api_enabled do
      case Chain.hash_to_address(hash) do
        {:error, :not_found} -> {:error, "Address not found."}
        {:ok, _} = result -> result
      end
    else
      {:error, Helper.api_is_disabled()}
    end
  end
end
