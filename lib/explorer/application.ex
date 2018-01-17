defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(Explorer.Repo, []),
      # Start the endpoint when the application starts
      supervisor(ExplorerWeb.Endpoint, []),
      # Start your own worker by calling: Explorer.Worker.start_link(a, b, c)
      # worker(Explorer.Worker, [a, b, c]),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Explorer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    alias ExplorerWeb.Endpoint
    Endpoint.config_change(changed, removed)
    :ok
  end
end
