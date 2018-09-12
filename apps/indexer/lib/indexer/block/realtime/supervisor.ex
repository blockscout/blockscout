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
          transport_options = Keyword.fetch!(subscribe_named_arguments, :transport_options)
          url = Keyword.fetch!(transport_options, :url)
          web_socket_module = Keyword.fetch!(transport_options, :web_socket)
          web_socket = Indexer.Block.Realtime.WebSocket

          block_fetcher_subscribe_named_arguments =
            put_in(subscribe_named_arguments[:transport_options][:web_socket_options], %{web_socket: web_socket})

          [
            {web_socket_module, [url, [name: web_socket]]},
            {Indexer.Block.Realtime.Fetcher,
             [
               %{block_fetcher: block_fetcher, subscribe_named_arguments: block_fetcher_subscribe_named_arguments},
               [name: Indexer.Block.Realtime.Fetcher]
             ]}
          ]
      end

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
