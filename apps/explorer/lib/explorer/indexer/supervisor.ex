defmodule Explorer.Indexer.Supervisor do
  @moduledoc """
  Supervising the fetchers for the `Explorer.Indexer`
  """

  use Supervisor

  alias Explorer.BufferedTask
  alias Explorer.Indexer.{AddressBalanceFetcher, BlockFetcher}

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      {Task.Supervisor, name: Explorer.Indexer.TaskSupervisor},
      {BufferedTask, {AddressBalanceFetcher, max_batch_size: 100, max_concurrency: 2, name: AddressBalanceFetcher}},
      {BlockFetcher, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
