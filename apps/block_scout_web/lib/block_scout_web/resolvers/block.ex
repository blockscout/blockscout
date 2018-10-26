defmodule BlockScoutWeb.Resolvers.Block do
  @moduledoc false

  alias Explorer.Chain

  def get_by(_, %{number: number}, _) do
    case Chain.number_to_block(number) do
      {:ok, _} = result -> result
      {:error, :not_found} -> {:error, "Block number #{number} was not found."}
    end
  end
end
