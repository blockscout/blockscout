defmodule Explorer.Indexer do
  @moduledoc """
  TODO
  """

  alias Explorer.Chain
  alias Explorer.Chain.Block

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
  TODO
  """
  def last_indexed_block_number do
    case Chain.get_latest_block() do
      %Block{number: num} -> num
      nil -> 0
    end
  end

  @doc """
  TODO
  """
  def next_block_number do
    case last_indexed_block_number() do
      0 -> 0
      num -> num + 1
    end
  end
end
