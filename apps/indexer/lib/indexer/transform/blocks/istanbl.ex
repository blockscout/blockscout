defmodule Indexer.Transform.Blocks.Istanbl do
    @moduledoc """
    Handles block transforms for Istanbl chain.
    """
  
    alias Indexer.Transform.Blocks
  
    @behaviour Blocks
  
    @impl Blocks
    def transform(%{number: 0} = block), do: block
  
    def transform(block) when is_map(block) do
      miner_address = Blocks.istanbl_signer(block)
      %{block | miner_hash: miner_address}
    end
  end
  