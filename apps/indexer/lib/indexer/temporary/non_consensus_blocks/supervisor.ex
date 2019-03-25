defmodule Indexer.Temporary.NonConsensusBlocks.Supervisor do
  @moduledoc """
  Supervises `Indexer.Temporary.NonConsensusBlocks`.
  """

  use Supervisor

  alias Indexer.Temporary.NonConsensusBlocks

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

  def start_link(fetcher, gen_server_options \\ []) do
    Supervisor.start_link(__MODULE__, fetcher, gen_server_options)
  end

  @impl Supervisor
  def init(fetcher) do
    Supervisor.init(
      [
        {Task.Supervisor, name: Indexer.Temporary.NonConsensusBlocks.TaskSupervisor},
        {NonConsensusBlocks, [fetcher, [name: NonConsensusBlocks]]}
      ],
      strategy: :rest_for_one
    )
  end
end
