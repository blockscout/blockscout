defmodule Indexer.Fetcher.Signet.OrdersFetcher.Supervisor do
  @moduledoc """
  Supervises the Signet OrdersFetcher and its task supervisor.
  """

  use Supervisor

  alias Indexer.Fetcher.Signet.OrdersFetcher

  def child_spec(init_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [init_arg]},
      type: :supervisor
    }
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def disabled? do
    config = Application.get_env(:indexer, OrdersFetcher, [])
    not Keyword.get(config, :enabled, false)
  end

  @impl Supervisor
  def init(init_arg) do
    children = [
      {Task.Supervisor, name: OrdersFetcher.TaskSupervisor},
      {OrdersFetcher, init_arg}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
