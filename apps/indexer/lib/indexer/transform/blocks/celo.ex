defmodule Indexer.Transform.Blocks.Celo do
  @moduledoc """
  Default block transformer to be used.
  """

  alias Explorer.Celo.AccountReader
  alias Indexer.Transform.Blocks

  @behaviour Blocks

  @impl Blocks
  def transform(block) when is_map(block) do
    case AccountReader.block_gas_limit(block.number) do
      {:ok, limit} -> Map.put(block, :gas_limit, limit)
      :error -> block
    end
  end
end
