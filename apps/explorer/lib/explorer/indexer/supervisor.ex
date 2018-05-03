defmodule Explorer.Indexer.Supervisor do
  @moduledoc """
  Supervising the fetchers for the `Explorer.Indexer`
  """

  use Supervisor

  alias Explorer.Indexer.{
    BlockFetcher,
    AddressFetcher
  }

  # Functions

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  ## Supervisor callbacks

  @impl Supervisor
  def init(_opts) do
    children = [
      {Task.Supervisor, name: Explorer.Indexer.TaskSupervisor},
      {BlockFetcher, []},
      {AddressFetcher, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
