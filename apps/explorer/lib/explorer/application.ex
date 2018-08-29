defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  @impl Application
  def start(_type, _args) do
    register_metrics()

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
      configure(Explorer.Market.History.Cataloger)
    ]
    |> List.flatten()
  end

  defp register_metrics do
    if Code.ensure_loaded(Wobserver) == {:module, Wobserver} do
      Wobserver.register(:page, {"Explorer", :explorer, &Explorer.Wobserver.page/0})
      Wobserver.register(:metric, &Explorer.Wobserver.metrics/0)
    end
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
