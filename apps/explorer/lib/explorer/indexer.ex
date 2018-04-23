defmodule Explorer.Indexer do
  @moduledoc """
  Indexers an Ethereum-based chain using JSONRPC.
  """

  alias Explorer.Chain
  alias Explorer.Chain.Block

  # Functions

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {Explorer.Indexer.Supervisor, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :supervisor
    }
  end

  def last_indexed_block_number do
    case Chain.get_latest_block() do
      %Block{number: num} -> num
      nil -> 0
    end
  end

  def next_block_number do
    case last_indexed_block_number() do
      0 -> 0
      num -> num + 1
    end
  end
end
