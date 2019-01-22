defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  alias Explorer.Admin
  alias Explorer.Repo.PrometheusLogger

  @impl Application
  def start(_type, _args) do
    PrometheusLogger.setup()

    :telemetry.attach(
      "prometheus-ecto",
      [:explorer, :repo, :query],
      &PrometheusLogger.handle_event/4,
      %{}
    )

    # Children to start in all environments
    base_children = [
      Explorer.Repo,
      Supervisor.Spec.worker(SpandexDatadog.ApiServer, [datadog_opts()]),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.MarketTaskSupervisor}, id: Explorer.MarketTaskSupervisor),
      Supervisor.child_spec({Task.Supervisor, name: Explorer.TaskSupervisor}, id: Explorer.TaskSupervisor),
      {Registry, keys: :duplicate, name: Registry.ChainEvents, id: Registry.ChainEvents},
      {Admin.Recovery, [[], [name: Admin.Recovery]]}
    ]

    children = base_children ++ configurable_children()

    opts = [strategy: :one_for_one, name: Explorer.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp configurable_children do
    [
      configure(Explorer.ExchangeRates),
      configure(Explorer.KnownTokens),
      configure(Explorer.Market.History.Cataloger),
      configure(Explorer.Counters.AddressesWithBalanceCounter),
      configure(Explorer.Counters.AverageBlockTime),
      configure(Explorer.Validator.MetadataProcessor)
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

  defp datadog_opts do
    [
      host: System.get_env("DATADOG_HOST") || "localhost",
      port: System.get_env("DATADOG_PORT") || 8126,
      batch_size: System.get_env("SPANDEX_BATCH_SIZE") || 100,
      sync_threshold: System.get_env("SPANDEX_SYNC_THRESHOLD") || 100,
      http: HTTPoison
    ]
  end
end
