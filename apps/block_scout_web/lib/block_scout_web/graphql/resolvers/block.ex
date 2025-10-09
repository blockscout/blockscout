defmodule BlockScoutWeb.GraphQL.Resolvers.Block do
  @moduledoc false

  alias Explorer.Chain
  alias Explorer.Chain.Transaction

  @api_true [api?: true]

  def get_by(_, %{number: number}, _) do
    number
    |> Chain.number_to_block(@api_true)
    |> case do
      {:ok, _} = result ->
        result

      {:error, :not_found} ->
        {:error, "Block number #{number} was not found."}
    end
  end

  def get_by(%Transaction{block_hash: hash}, _, _) do
    hash
    |> Chain.hash_to_block(@api_true)
    |> case do
      {:ok, _} = result ->
        result

      {:error, :not_found} ->
        {:error, "Block hash #{to_string(hash)} was not found."}
    end
  end
end
