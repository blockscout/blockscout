defmodule Indexer.Block.Catchup.Supervisor do
  @moduledoc """
  Supervises `Indexer.Block.Catchup.TaskSupervisor` and `Indexer.Block.Catchup.BoundIntervalSupervisor`
  """

  use Supervisor

  alias Indexer.Block.Catchup.{BoundIntervalSupervisor, MassiveBlocksFetcher, MissingRangesCollector}

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      type: :supervisor
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(arguments, gen_server_options \\ []) do
    Supervisor.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl Supervisor
  def init(bound_interval_supervisor_arguments) do
    Supervisor.init(
      [
        {MissingRangesCollector, []},
        {Task.Supervisor, name: Indexer.Block.Catchup.TaskSupervisor},
        {MassiveBlocksFetcher, []},
        {BoundIntervalSupervisor, [bound_interval_supervisor_arguments, [name: BoundIntervalSupervisor]]}
      ],
      strategy: :one_for_one
    )
  end
end
