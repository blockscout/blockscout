defmodule Indexer.Block.Uncle.Supervisor do
  @moduledoc """
  Supervises `Indexer.Block.Uncle.Fetcher`.
  """

  use Supervisor

  alias Indexer.Block.Uncle.Fetcher

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
  def init(fetcher_arguments) do
    Supervisor.init(
      [
        {Task.Supervisor, name: Indexer.Block.Uncle.TaskSupervisor},
        {Fetcher, [fetcher_arguments, [name: Fetcher]]}
      ],
      strategy: :rest_for_one
    )
  end
end
