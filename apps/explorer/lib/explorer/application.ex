defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  import Supervisor.Spec, only: [supervisor: 3]

  # Functions

  ## Application callbacks

  @impl Application
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Explorer.Supervisor]
    Supervisor.start_link(children(Mix.env()), opts)
  end

  ## Private Functions

  defp children(:test), do: children()

  defp children(_) do
    children() ++
      [
        Explorer.JSONRPC,
        supervisor(Task.Supervisor, [[name: Explorer.TaskSupervisor]], id: Explorer.TaskSupervisor),
        Explorer.Indexer,
        Explorer.Chain.Statistics.Server,
        Explorer.ExchangeRates
      ]
  end

  defp children do
    [
      Explorer.Repo,
      supervisor(
        Task.Supervisor,
        [[name: Explorer.ExchangeRateTaskSupervisor]],
        id: Explorer.ExchangeRateTaskSupervisor
      )
    ]
  end
end
