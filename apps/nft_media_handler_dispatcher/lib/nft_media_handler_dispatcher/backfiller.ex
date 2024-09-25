defmodule NFTMediaHandlerDispatcher.Backfiller do
  @moduledoc """
  Module fetches from DB token instances which wasn't processed via NFTMediaHandler yet. Then put it to the queue.
  Via get_instances/1 it's possible to get urls to fetch.
  """
  alias Explorer.Chain.Token.Instance

  import NFTMediaHandlerDispatcher, only: [get_media_url_from_metadata: 1]

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

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

  defp enqueue_if_queue_is_not_full(instance) do
    url = get_media_url_from_metadata(instance.metadata)

    if !is_nil(url) do
      if GenServer.call(__MODULE__, :not_full?) do
        GenServer.cast(__MODULE__, {:append_to_queue, {url, instance.token_contract_address_hash, instance.token_id}})
      else
        :timer.sleep(enqueue_timeout())

        enqueue_if_queue_is_not_full(instance)
      end
    end
  end

  @impl true
  def handle_call(:not_full?, _from, %{queue: queue} = state) do
    {:reply, Enum.count(queue) < max_queue_size(), state}
  end

  @impl true
  def handle_call({:get_instances, amount}, _from, %{queue: queue} = state) do
    {to_return, remaining} = Enum.split(queue, amount)
    {:reply, to_return, %{state | queue: remaining |> Enum.into(%{})}}
  end

  @impl true
  def handle_cast({:append_to_queue, {url, token_contract_address_hash, token_id}}, %{queue: queue} = state) do
    {:noreply, %{state | queue: Map.put(queue, url, [{token_contract_address_hash, token_id} | queue[url] || []])}}
  end

  @impl true
  def handle_info({ref, _answer}, %{ref_to_stream_task: ref} = state) do
    {:noreply, %{state | stream_is_over?: true}}
  end

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
