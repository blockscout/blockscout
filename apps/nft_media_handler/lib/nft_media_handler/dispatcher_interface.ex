defmodule NFTMediaHandler.DispatcherInterface do
  @moduledoc """
  Interface to call the Indexer.NFTMediaHandler.Queue.
  Calls performed either via direct call to Queue module, or via :rpc.call/4
  """
  require Logger
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Initializes the dispatcher interface.
  """
  @impl true
  def init(_) do
    nodes = :nft_media_handler |> Application.get_env(:nodes_map) |> Map.to_list()

    if Enum.empty?(nodes) do
      {:stop, "NFT_MEDIA_HANDLER_NODES_MAP must contain at least one node"}
    else
      {:ok, %{used_nodes: [], unused_nodes: nodes}}
    end
  end

  @doc """
  Handles the `:take_node_to_call` call message.
  Takes a node from the list of nodes to call. Nodes rotate in a round-robin fashion.
  """
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

  @doc """
  Retrieves a list of URLs.

  ## Parameters
  - amount: The number of URLs to retrieve.

  ## Returns
  {list_of_urls, node_where_urls_from, r2_folder_to_store_images}
  """
  @spec get_urls(non_neg_integer()) :: {list(), atom(), String.t()}
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

  @doc """
  Stores the result of the media fetching process. If the remote flag is set to true, the result will be stored in a remote node.
  """
  @spec store_result(any(), atom()) :: any()
  def store_result(batch_result, node) do
    remote_call([batch_result], :store_result, node, Application.get_env(:nft_media_handler, :remote?))
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
