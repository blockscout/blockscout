defmodule BlockScoutWeb.Resolvers.Address do
  @moduledoc false

  alias Explorer.Chain

  def get_by(_, %{hashes: hashes}, _) do
    case Chain.hashes_to_addresses(hashes) do
      [] -> {:error, "Addresses not found."}
      result -> {:ok, result}
    end
  end
end
