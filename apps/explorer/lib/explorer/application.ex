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
      %{
        id: Exq,
        start: {Exq, :start_link, [[mode: :enqueuer]]},
        type: :supervisor
      },
      Explorer.Chain.Statistics.Server,
      Explorer.ExchangeRates,
      Explorer.Market.History.Cataloger
    ]
  end
end
