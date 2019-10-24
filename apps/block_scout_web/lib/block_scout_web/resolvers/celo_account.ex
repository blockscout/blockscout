defmodule BlockScoutWeb.Resolvers.CeloAccount do
    @moduledoc false
  
    alias Explorer.Chain
  
    def get_by(_, %{hash: hash}, _) do
      case Chain.get_celo_account(hash) do
        {:error, :not_found} -> {:error, "Celo account not found."}
        {:ok, _} = result -> result
      end
    end
end

