defmodule NFTMediaHandler.DispatcherInterface do
  @moduledoc """
  Documentation for `NFTMediaHandler.DispatcherInterface`.
  """
  require Logger
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    nodes = :nft_media_handler |> Application.get_env(:nodes_map) |> Map.to_list()

    if Enum.empty?(nodes) do
      {:stop, "NFT_MEDIA_HANDLER_NODES_MAP must contain at least one node"}
    else
      {:ok, %{used_nodes: [], unused_nodes: nodes}}
    end
  end

  @impl true
  def handle_call(:take_node_to_call, _from, %{used_nodes: used_nodes, unused_nodes: unused_nodes}) do
    {used, unused, node_to_call} =
      case unused_nodes do
        [] ->
          [to_call | remains] = used_nodes |> Enum.reverse()
          {[to_call], remains, to_call}

        [to_call | remains] ->
          {[to_call | used_nodes], remains, to_call}
      end

    {:reply, node_to_call, %{used_nodes: used, unused_nodes: unused}}
  end

  def get_urls(amount) do
    args = [amount]
    function = :get_urls_to_fetch

    if Application.get_env(:nft_media_handler, :remote?) do
      {node, folder} = GenServer.call(__MODULE__, :take_node_to_call)

      {node |> :rpc.call(Indexer.NFTMediaHandler.Queue, :get_urls_to_fetch, args) |> process_rpc_response(node), node,
       folder}
    else
      folder = Application.get_env(:nft_media_handler, :nodes_map)[:self]
      {apply(Indexer.NFTMediaHandler.Queue, function, args), :self, folder}
    end
  end

  def store_result(result, url, node) do
    remote_call([result, url], :store_result, node, Application.get_env(:nft_media_handler, :remote?))
  end

  def remote_node do
    Application.get_env(:nft_media_handler, :dispatcher_node)
  end

  defp remote_call(args, function, node, true) do
    :rpc.call(node, Indexer.NFTMediaHandler.Queue, function, args)
  end

  defp remote_call(args, function, _node, false) do
    apply(Indexer.NFTMediaHandler.Queue, function, args)
  end

  defp process_rpc_response({:badrpc, _reason} = error, node) do
    Logger.error("Received an error from #{node}: #{inspect(error)}")
    []
  end

  defp process_rpc_response(response, _node), do: response
end
