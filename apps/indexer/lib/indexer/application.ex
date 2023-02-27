defmodule Indexer.Application do
  @moduledoc """
  This is the `Application` module for `Indexer`.
  """

  use Application

  alias Indexer.Fetcher.{CoinBalanceOnDemand, FirstTraceOnDemand, TokenTotalSupplyOnDemand}
  alias Indexer.Memory
  alias Indexer.Prometheus.PendingBlockOperationsCollector
  alias Prometheus.Registry

  @impl Application
  def start(_type, _args) do
    Registry.register_collector(PendingBlockOperationsCollector)

    memory_monitor_options =
      case Application.get_env(:indexer, :memory_limit) do
        nil -> %{}
        integer when is_integer(integer) -> %{limit: integer}
      end

    memory_monitor_name = Memory.Monitor

    json_rpc_named_arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)

    base_children = [
      {Memory.Monitor, [memory_monitor_options, [name: memory_monitor_name]]},
      {CoinBalanceOnDemand.Supervisor, [json_rpc_named_arguments]},
      {TokenTotalSupplyOnDemand.Supervisor, []},
      {FirstTraceOnDemand.Supervisor, [json_rpc_named_arguments]}
    ]

    children =
      if Application.get_env(:indexer, Indexer.Supervisor)[:enabled] do
        Enum.reverse([{Indexer.Supervisor, [%{memory_monitor: memory_monitor_name}]} | base_children])
      else
        base_children
      end

    opts = [
      # If the `Memory.Monitor` dies, it needs all the `Shrinkable`s to re-register, so restart them.
      strategy: :rest_for_one,
      name: Indexer.Application
    ]

    Supervisor.start_link(children, opts)
  end
end
