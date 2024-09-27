defmodule BlockScoutWeb.GraphQL.Resolvers.Block do
  @moduledoc false

  alias BlockScoutWeb.GraphQL.Resolvers.Helper
  alias Explorer.Chain
  alias Explorer.Chain.Transaction

  @api_true [api?: true]

  def get_by(_, %{number: number}, resolution) do
    with {:api_enabled, true} <- {:api_enabled, resolution.context.api_enabled},
         {:ok, _} = result <- Chain.number_to_block(number, @api_true) do
      result
    else
      {:api_enabled, false} -> {:error, Helper.api_is_disabled()}
      {:error, :not_found} -> {:error, "Block number #{number} was not found."}
    end
  end

  def get_by(%Transaction{block_hash: hash}, _, resolution) do
    with {:api_enabled, true} <- {:api_enabled, resolution.context.api_enabled},
         {:ok, _} = result <- Chain.hash_to_block(hash, @api_true) do
      result
    else
      {:api_enabled, false} -> {:error, Helper.api_is_disabled()}
      {:error, :not_found} -> {:error, "Block hash #{to_string(hash)} was not found."}
    end
  end
end
