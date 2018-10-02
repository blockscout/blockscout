defmodule BlockScoutWeb.Application do
  @moduledoc """
  Supervises `BlockScoutWeb.Endpoint` in order to serve Web UI.
  """

  use Application

  alias BlockScoutWeb.{Endpoint, EventHandler, Prometheus}

  def start(_type, _args) do
    import Supervisor.Spec

    Prometheus.Instrumenter.setup()
    Prometheus.Exporter.setup()

    # Define workers and child supervisors to be supervised
    children = [
      # Start the endpoint when the application starts
      supervisor(Endpoint, []),
      {EventHandler, name: EventHandler}
      # Start your own worker by calling: PoaexpWeb.Worker.start_link(arg1, arg2, arg3)
      # worker(PoaexpWeb.Worker, [arg1, arg2, arg3]),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BlockScoutWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end
end
