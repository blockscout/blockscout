defmodule Indexer.RollupReorgMonitorQueue do
  @moduledoc """
  Queue registry used by rollup reorg monitoring fetchers.
  """

  use Explorer.ModuleQueueRegistry

  # sobelow_skip ["DOS.BinToAtom"]
  @impl true
  @spec table_name(module()) :: atom()
  def table_name(module) do
    :"#{module}#{:_reorgs}"
  end
end
