defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  alias Explorer.Repo.PrometheusLogger

  @impl Application
  def start(_type, _args) do
    PrometheusLogger.setup()

    # Children to start in all environments
    base_children = [
      Explorer.Repo,
      Supervisor.child_spec({Task.Supervisor, name: Explorer.MarketTaskSupervisor}, id: Explorer.MarketTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.TaskSupervisor}, id: Explorer.TaskSupervisor),
      {Registry, keys: :duplicate, name: Registry.ChainEvents, id: Registry.ChainEvents}
    ]

    children = base_children ++ configurable_children()

    opts = [strategy: :one_for_one, name: Explorer.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp configurable_children do
    [
      configure(Explorer.ExchangeRates),
      configure(Explorer.Market.History.Cataloger),
      configure(Explorer.Counters.TokenTransferCounter),
      configure(Explorer.Counters.TransactionCounter)
    ]
    |> List.flatten()
  end

  defp should_start?(process) do
    :explorer
    |> Application.fetch_env!(process)
    |> Keyword.fetch!(:enabled)
  end

  defp configure(process) do
    if should_start?(process) do
      process
    else
      []
    end
  end
end
