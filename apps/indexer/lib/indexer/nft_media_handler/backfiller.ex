defmodule Indexer.NFTMediaHandler.Backfiller do
  @moduledoc """
  Module fetches from DB token instances which wasn't processed via NFTMediaHandler yet. Then put it to the queue.
  Via get_instances/1 it's possible to get urls to fetch.
  """
  alias Explorer.Chain.Token.Instance

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Retrieves a specified number of instances from the queue.

  ## Parameters
  - amount: The number of instances to retrieve.

  ## Returns
  A list of instances.
  """
  @spec get_instances(non_neg_integer) :: list
  def get_instances(amount) do
    if config()[:enabled?] do
      GenServer.call(__MODULE__, {:get_instances, amount})
    else
      []
    end
  end

  @impl true
  def init(_) do
    %{ref: ref} =
      Task.async(fn ->
        Instance.stream_instances_to_resize_and_upload(&enqueue_if_queue_is_not_full/1)
      end)

    {:ok, %{queue: %{}, ref_to_stream_task: ref, stream_is_over?: false}}
  end

  # Enqueues the given instance if the queue is not full.
  # if queue is full, it will wait enqueue_timeout() and call self again.
  defp enqueue_if_queue_is_not_full(instance) do
    url = Instance.get_media_url_from_metadata_for_nft_media_handler(instance.metadata)

    if !is_nil(url) do
      if GenServer.call(__MODULE__, :not_full?) do
        GenServer.cast(__MODULE__, {:append_to_queue, {url, instance.token_contract_address_hash, instance.token_id}})
      else
        :timer.sleep(enqueue_timeout())

        enqueue_if_queue_is_not_full(instance)
      end
    end
  end

  # Handles the `:not_full?` call message.
  # Returns whether the queue is not full.

  @impl true
  def handle_call(:not_full?, _from, %{queue: queue} = state) do
    {:reply, Enum.count(queue) < max_queue_size(), state}
  end

  # Handles the `:get_instances` call message.
  # Returns a specified number of instances from the queue.
  @impl true
  def handle_call({:get_instances, amount}, _from, %{queue: queue} = state) do
    {to_return, remaining} = Enum.split(queue, amount)
    {:reply, to_return, %{state | queue: remaining |> Enum.into(%{})}}
  end

  # Handles the `:append_to_queue` cast message.
  # Appends the given URL, token contract address hash, and token ID to the queue in the state.
  @impl true
  def handle_cast({:append_to_queue, {url, token_contract_address_hash, token_id}}, %{queue: queue} = state) do
    {:noreply, %{state | queue: Map.put(queue, url, [{token_contract_address_hash, token_id} | queue[url] || []])}}
  end

  # Handles the termination of the stream task.
  @impl true
  def handle_info({ref, _answer}, %{ref_to_stream_task: ref} = state) do
    {:noreply, %{state | stream_is_over?: true}}
  end

  # Handles the termination of the stream task.
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{ref_to_stream_task: ref} = state) do
    {:noreply, %{state | stream_is_over?: true}}
  end

  defp max_queue_size do
    config()[:queue_size]
  end

  defp enqueue_timeout do
    config()[:enqueue_busy_waiting_timeout]
  end

  defp config do
    Application.get_env(:nft_media_handler, __MODULE__)
  end
end
