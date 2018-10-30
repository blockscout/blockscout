defmodule Indexer.Block.Transform.Base do
  @moduledoc """
  Default block transformer to be used.
  """

  alias Indexer.Block.Transform

  @behaviour Transform

  @impl Transform
  def transform(block) when is_map(block) do
    block
  end
end
