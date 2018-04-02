defmodule Explorer.Indexer.Supervisor do
  @moduledoc """
  Supervising the fetchers for the `Explorer.Indexer`
  """

  alias Explorer.Indexer.BlockFetcher

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(_opts) do
    children = [
      {BlockFetcher, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
