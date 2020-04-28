defmodule Indexer.Transform.Blocks.Celo do
  @moduledoc """
  Default block transformer to be used.
  """

  alias Indexer.Transform.Blocks
  alias Explorer.Celo.AccountReader

  @behaviour Blocks

  @impl Blocks
  def transform(block) when is_map(block) do
    with {:ok, limit} <- AccountReader.block_gas_limit(block.number) do
      Map.put(block, :gas_limit, limit)
    else
      _ -> block
    end
  end
end
