defmodule Indexer.Block.Transform do
  @moduledoc """
  Protocol for transforming blocks.
  """

  @type block :: map()

  @doc """
  Transforms a block.
  """
  @callback transform(block :: block()) :: block()

  @doc """
  Runs a list of blocks through the configured block transformer.
  """
  def transform_blocks(blocks) when is_list(blocks) do
    transformer = Application.get_env(:indexer, :block_transformer)

    unless transformer do
      raise ArgumentError,
            """
            No block transformer defined. Set a blocker transformer."

               config :indexer,
                 block_transformer: Indexer.Block.Transform.Base
            """
    end

    Enum.map(blocks, &transformer.transform/1)
  end
end
