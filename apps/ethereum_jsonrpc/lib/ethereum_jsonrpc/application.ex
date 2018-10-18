defmodule EthereumJSONRPC.Application do
  @moduledoc """
  Starts `:hackney_pool` `:ethereum_jsonrpc`.
  """

  use Application

  alias EthereumJSONRPC.{RollingWindow, TimeoutCounter, RequestCoordinator}

  @impl Application
  def start(_type, _args) do
    rolling_window_opts =
      :ethereum_jsonrpc,
      |> Application.fetch_env!(RequestCoordinator)
      |> Keyword.fetch!(:rolling_window_opts)

    children = [
      :hackney_pool.child_spec(:ethereum_jsonrpc, recv_timeout: 60_000, timeout: 60_000, max_connections: 1000),
      {RollingWindow, [rolling_window_opts]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: EthereumJSONRPC.Supervisor)
  end
end
