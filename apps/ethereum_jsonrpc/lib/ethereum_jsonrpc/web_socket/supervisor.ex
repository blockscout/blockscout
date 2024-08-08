defmodule EthereumJSONRPC.WebSocket.Supervisor do
  @moduledoc """
  Supervises the processes related to `EthereumJSONRPC.WebSocket`.
  """

  use Supervisor

  alias EthereumJSONRPC.WebSocket.RetryWorker

  def start_link(transport_options) do
    Supervisor.start_link(__MODULE__, transport_options, name: __MODULE__)
  end

  def start_client(ws_state) do
    subscribe_named_arguments =
      Application.get_env(:indexer, :realtime_overrides)[:subscribe_named_arguments] ||
        Application.get_env(:indexer, :subscribe_named_arguments)

    web_socket_module =
      subscribe_named_arguments
      |> Keyword.fetch!(:transport_options)
      |> Keyword.fetch!(:web_socket)

    client_spec = client_spec(web_socket_module, Indexer.Block.Realtime.WebSocketCopy, ws_state.url, nil, ws_state)

    Supervisor.start_child(__MODULE__, client_spec)
  end

  def stop_other_client(pid) do
    __MODULE__
    |> Supervisor.which_children()
    |> Enum.reject(fn {child_id, child_pid, _type, _modules} -> child_pid == pid or child_id == RetryWorker end)
    |> Enum.each(fn {child_id, _child_pid, _type, _modules} ->
      Supervisor.terminate_child(__MODULE__, child_id)
      Supervisor.delete_child(__MODULE__, child_id)
      Process.unregister(Indexer.Block.Realtime.WebSocketCopy)
      Process.register(pid, Indexer.Block.Realtime.WebSocket)
    end)
  end

  def init(%{
        url: url,
        fallback_url: fallback_url,
        web_socket: web_socket_module,
        web_socket_options: %{web_socket: web_socket}
      }) do
    children = [
      {RetryWorker, []},
      client_spec(web_socket_module, web_socket, url, fallback_url)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp client_spec(web_socket_module, name, url, fallback_url, init_state \\ nil) do
    %{
      id: name,
      start: {
        web_socket_module,
        :start_link,
        [url, [name: name, fallback_url: fallback_url, init_state: init_state]]
      },
      restart: :temporary
    }
  end
end
