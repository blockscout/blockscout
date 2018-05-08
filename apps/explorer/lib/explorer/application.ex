defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  import Supervisor.Spec, only: [supervisor: 3]

  @impl Application
  def start(_type, _args) do
    # Children to start in all environments
    base_children = [
      Explorer.Repo,
      {Task.Supervisor, name: Explorer.MarketTaskSupervisor}
    ]

    children = base_children ++ secondary_children(Mix.env())

    opts = [strategy: :one_for_one, name: Explorer.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp secondary_children(:test), do: []

  # Children to start when not testing
  defp secondary_children(_) do
    [
      Explorer.JSONRPC,
      supervisor(Task.Supervisor, [[name: Explorer.TaskSupervisor]], id: Explorer.TaskSupervisor),
      Explorer.Indexer,
      Explorer.Chain.Statistics.Server,
      Explorer.ExchangeRates,
      Explorer.Market.History.Cataloger
    ]
  end
end
