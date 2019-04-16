defmodule Indexer.Block.Realtime.Supervisor do
  @moduledoc """
  Supervises realtime block fetcher.
  """

  use Supervisor

  def start_link([arguments, gen_server_options]) do
    Supervisor.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl Supervisor
  def init(%{block_fetcher: block_fetcher, subscribe_named_arguments: subscribe_named_arguments}) do
    children =
      case Keyword.fetch!(subscribe_named_arguments, :transport) do
        EthereumJSONRPC.WebSocket ->
          transport_options =
            struct!(EthereumJSONRPC.WebSocket, Keyword.fetch!(subscribe_named_arguments, :transport_options))

          web_socket = Indexer.Block.Realtime.WebSocket
          web_socket_options = %EthereumJSONRPC.WebSocket.WebSocketClient.Options{web_socket: web_socket}
          transport_options = %EthereumJSONRPC.WebSocket{transport_options | web_socket_options: web_socket_options}
          %EthereumJSONRPC.WebSocket{url: url, web_socket: web_socket_module} = transport_options

          keepalive = Keyword.get(subscribe_named_arguments, :keep_alive, :timer.seconds(150))

          block_fetcher_subscribe_named_arguments =
            put_in(subscribe_named_arguments[:transport_options], transport_options)

          [
            {Task.Supervisor, name: Indexer.Block.Realtime.TaskSupervisor},
            {web_socket_module, [url, [keepalive: keepalive], [name: web_socket]]},
            {Indexer.Block.Realtime.Fetcher,
             [
               %{block_fetcher: block_fetcher, subscribe_named_arguments: block_fetcher_subscribe_named_arguments},
               [name: Indexer.Block.Realtime.Fetcher]
             ]}
          ]

        _ ->
          [
            {Task.Supervisor, name: Indexer.Block.Realtime.TaskSupervisor},
            {Indexer.Block.Realtime.Fetcher,
             [
               %{block_fetcher: block_fetcher, subscribe_named_arguments: nil},
               [name: Indexer.Block.Realtime.Fetcher]
             ]}
          ]
      end

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
