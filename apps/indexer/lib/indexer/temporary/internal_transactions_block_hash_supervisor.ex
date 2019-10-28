defmodule Indexer.Temporary.InternalTransactionsBlockHash.Supervisor do
  @moduledoc """
  Supervises `Indexer.Temporary.InternalTransactionsBlockHash`.
  """

  use Supervisor

  alias Indexer.Temporary.InternalTransactionsBlockHash

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec(start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      type: :supervisor
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(gen_server_options \\ []) do
    Supervisor.start_link(__MODULE__, [], gen_server_options)
  end

  @impl Supervisor
  def init(_) do
    Supervisor.init(
      [
        {Task.Supervisor, name: Indexer.Temporary.InternalTransactionsBlockHash.TaskSupervisor},
        {InternalTransactionsBlockHash, [name: InternalTransactionsBlockHash]}
      ],
      strategy: :rest_for_one
    )
  end
end
