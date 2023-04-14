defmodule EthereumJSONRPC.Application do
  @moduledoc """
  Starts `:hackney_pool` `:ethereum_jsonrpc`.
  """

  use Application

  alias EthereumJSONRPC.{IPC, RequestCoordinator, RollingWindow}
  alias EthereumJSONRPC.Utility.{EndpointAvailabilityChecker, EndpointAvailabilityObserver}

  @impl Application
  def start(_type, _args) do
    config = Application.fetch_env!(:ethereum_jsonrpc, RequestCoordinator)

    rolling_window_opts = Keyword.fetch!(config, :rolling_window_opts)

    [
      :hackney_pool.child_spec(:ethereum_jsonrpc, recv_timeout: 60_000, timeout: 60_000, max_connections: 1000),
      Supervisor.child_spec({RollingWindow, [rolling_window_opts]}, id: RollingWindow.ErrorThrottle),
      {EndpointAvailabilityObserver, []},
      {EndpointAvailabilityChecker, []}
    ]
    |> add_throttle_rolling_window(config)
    |> add_ipc_client()
    |> Supervisor.start_link(strategy: :one_for_one, name: EthereumJSONRPC.Supervisor)
  end

  defp add_throttle_rolling_window(children, config) do
    if config[:throttle_rate_limit] do
      case Keyword.fetch(config, :throttle_rolling_window_opts) do
        {:ok, throttle_rolling_window_opts} ->
          child =
            Supervisor.child_spec({RollingWindow, [throttle_rolling_window_opts]}, id: RollingWindow.ThrottleRateLimit)

          [child | children]

        :error ->
          raise "If you have configured `:throttle_rate_limit` you must also configure `:throttle_rolling_window_opts`"
      end
    else
      children
    end
  end

  defp add_ipc_client(children) do
    case Application.get_env(:ethereum_jsonrpc, :rpc_transport) do
      :ipc ->
        [
          :poolboy.child_spec(:worker, poolboy_config(), path: Application.get_env(:ethereum_jsonrpc, :ipc_path))
          | children
        ]

      _ ->
        children
    end
  end

  defp poolboy_config do
    [
      {:name, {:local, :ipc_worker}},
      {:worker_module, IPC},
      {:size, 10},
      {:max_overflow, 5}
    ]
  end
end
