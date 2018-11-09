defmodule Indexer.Block.Transform.Clique do
  @moduledoc """
  Handles block transforms for Clique chain.
  """

  alias Indexer.Block.{Transform, Util}

  @behaviour Transform

  @impl Transform
  def transform(block) when is_map(block) do
    miner_address = Util.signer(block)

    %{block | miner_hash: miner_address}
  end
end
