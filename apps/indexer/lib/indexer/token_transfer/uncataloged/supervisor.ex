defmodule Indexer.TokenTransfer.Uncataloged.Supervisor do
  @moduledoc """
  Supervises process for ensuring uncataloged token transfers get queued for indexing.
  """

  use Supervisor

  alias Indexer.TokenTransfer.Uncataloged.Worker

  def child_spec([]) do
    child_spec([[]])
  end

  def child_spec([init_arguments]) do
    child_spec([init_arguments, [name: __MODULE__]])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :supervisor
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(init_arguments, gen_server_options \\ []) do
    Supervisor.start_link(__MODULE__, init_arguments, gen_server_options)
  end

  @impl Supervisor
  def init(_) do
    children = [
      {Worker, [[supervisor: self()], [name: Worker]]},
      {Task.Supervisor, name: Indexer.TokenTransfer.Uncataloged.TaskSupervisor}
    ]

    opts = [strategy: :one_for_all]

    Supervisor.init(children, opts)
  end
end
