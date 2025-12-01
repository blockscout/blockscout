defmodule NFTMediaHandler.DispatcherInterface do
  @moduledoc """
  Interface to call the Indexer.NFTMediaHandler.Queue.
  Calls performed either via direct call to Queue module, or via :rpc.call/4
  """
  require Logger
  use GenServer

  alias Explorer.Helper

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Initializes the dispatcher interface.
  """
  @impl true
  def init(_) do
    {:ok, nil, {:continue, 1}}
  end

  @impl true
  def handle_continue(attempt, _state) do
    attempt |> Kernel.**(3) |> :timer.seconds() |> :timer.sleep()

    get_indexer_nodes()
    |> case do
      [] ->
        if attempt < 5 do
          {:noreply, nil, {:continue, attempt + 1}}
        else
          raise "No indexer nodes discovered after #{attempt} attempts"
        end

      nodes ->
        {:noreply, %{used_nodes: [], unused_nodes: nodes}}
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
          get_indexer_nodes()
          |> case do
            [] ->
              raise "No indexer nodes discovered"

            [to_call | remains] ->
              {[to_call], remains, to_call}
          end

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
      node = GenServer.call(__MODULE__, :take_node_to_call)

      {urls, folder} =
        node |> :rpc.call(Indexer.NFTMediaHandler.Queue, function, args) |> Helper.process_rpc_response(node, {[], nil})

      {urls, node, folder}
    else
      {urls, folder} = apply(Indexer.NFTMediaHandler.Queue, function, args)
      {urls, :self, folder}
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

  defp get_indexer_nodes do
    Node.list()
    |> Enum.filter(&Helper.indexer_node?/1)
  end
end
