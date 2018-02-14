defmodule Explorer.Application do
  @moduledoc """
  This is the Application module for Explorer.
  """

  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Explorer.Supervisor]
    Supervisor.start_link(children(Mix.env), opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    alias ExplorerWeb.Endpoint
    Endpoint.config_change(changed, removed)
    :ok
  end

  defp children(:test), do: children()
  defp children(_) do
    import Supervisor.Spec
    exq_options = [] |> Keyword.put(:mode, :enqueuer)
    children() ++ [
      supervisor(Exq, [exq_options]),
      worker(Explorer.Servers.ChainStatistics, [])
    ]
  end

  defp children do
    import Supervisor.Spec
    [
      supervisor(Explorer.Repo, []),
      supervisor(ExplorerWeb.Endpoint, []),
    ]
  end
end
