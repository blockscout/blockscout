defmodule Indexer.TokenTransfer.Uncataloged.Supervisor do
  @moduledoc """
  Supervises process for ensuring uncataloged token transfers get queued for indexing.
  """

  use Supervisor

  alias Indexer.TokenTransfer.Uncataloged.Worker

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(_) do
    children = [
      %{
        id: Worker,
        start: {Worker, :start_link, [[supervisor: self()]]},
        restart: :transient
      },
      {Task.Supervisor, name: Indexer.TokenTransfer.Uncataloged.TaskSupervisor}
    ]

    opts = [strategy: :one_for_all, name: __MODULE__]

    Supervisor.init(children, opts)
  end
end
