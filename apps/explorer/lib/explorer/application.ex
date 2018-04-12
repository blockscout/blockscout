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
    Supervisor.start_link(children(Mix.env()), opts)
  end

  defp children(:test), do: children()

  defp children(_) do
    import Supervisor.Spec
    exq_options = [] |> Keyword.put(:mode, :enqueuer)

    children() ++
      [
        supervisor(Exq, [exq_options]),
        worker(Explorer.Servers.ChainStatistics, [])
      ]
  end

  defp children do
    import Supervisor.Spec

    [
      supervisor(Explorer.Repo, [])
    ]
  end
end
