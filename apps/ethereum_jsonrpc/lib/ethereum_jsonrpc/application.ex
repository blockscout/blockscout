defmodule EthereumJSONRPC.Application do
  @moduledoc """
  Starts `:hackney_pool` `:ethereum_jsonrpc`.
  """

  use Application

  alias EthereumJSONRPC.{RollingWindow, TimeoutCounter, RequestCoordinator}

  @impl Application
  def start(_type, _args) do
    children = [
      :hackney_pool.child_spec(:ethereum_jsonrpc, recv_timeout: 60_000, timeout: 60_000, max_connections: 1000),
      {RollingWindow, [RequestCoordinator.rolling_window_opts(), [name: TimeoutCounter]]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: EthereumJSONRPC.Supervisor)
  end
end
