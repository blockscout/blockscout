defmodule BlockScoutWeb.GraphQL.Resolvers.Block do
  @moduledoc false

  alias BlockScoutWeb.GraphQL.Resolvers.Helper
  alias Explorer.Chain

  def get_by(_, %{number: number}, resolution) do
    with {:api_enabled, true} <- {:api_enabled, resolution.context.api_enabled},
         {:ok, _} = result <- Chain.number_to_block(number) do
      result
    else
      {:api_enabled, false} -> {:error, Helper.api_is_disabled()}
      {:error, :not_found} -> {:error, "Block number #{number} was not found."}
    end
  end
end
