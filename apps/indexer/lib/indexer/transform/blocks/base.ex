defmodule Indexer.Transform.Blocks.Base do
  @moduledoc """
  Default block transformer to be used.
  """

  alias Indexer.Transform.Blocks

  @behaviour Blocks

  @impl Blocks
  def transform(block) when is_map(block) do
    block
  end
end
