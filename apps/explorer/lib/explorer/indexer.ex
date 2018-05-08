defmodule Explorer.Indexer do
  @moduledoc """
  Indexers an Ethereum-based chain using JSONRPC.
  """

  alias Explorer.Chain

  @doc """
  Options passed to `child_spec` are passed to `Explorer.Indexer.Supervisor.start_link/1`

      iex> Explorer.Indexer.child_spec([option: :value])
      %{
        id: Explorer.Indexer,
        restart: :permanent,
        shutdown: 5000,
        start: {Explorer.Indexer.Supervisor, :start_link,
         [[option: :value]]},
        type: :supervisor
      }

  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {Explorer.Indexer.Supervisor, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :supervisor
    }
  end

  @doc """
  The maximum `t:Explorer.Chain.Block.t/0` `number` that was indexed

  If blocks are skipped and inserted out of number order, the max number is still returned

      iex> insert(:block, number: 2)
      iex> insert(:block, number: 1)
      iex> Explorer.Indexer.max_block_number()
      2

  If there are no blocks, `0` is returned to indicate to index from genesis block.

      iex> Explorer.Indexer.max_block_number()
      0

  """
  def max_block_number do
    case Chain.max_block_number() do
      {:ok, number} -> number
      {:error, :not_found} -> 0
    end
  end

  @doc """
  The next `t:Explorer.Chain.Block.t/0` `number` that needs to be indexed (excluding skipped blocks)

  When there are no blocks the next block is the 0th block

      iex> Explorer.Indexer.max_block_number()
      0
      iex> Explorer.Indexer.next_block_number()
      0

  When there is a block, it is the successive block number

      iex> insert(:block, number: 2)
      iex> insert(:block, number: 1)
      iex> Explorer.Indexer.next_block_number()
      3

  """
  def next_block_number do
    case max_block_number() do
      0 -> 0
      num -> num + 1
    end
  end
end
