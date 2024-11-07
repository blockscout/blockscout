defmodule NFTMediaHandler.Dispatcher do
  @moduledoc """
  Module responsible for spawning tasks for uploading image
  and handling responses from that tasks
  """
  use GenServer

  alias Task.Supervisor, as: TaskSupervisor
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Process.send(self(), :spawn_tasks, [])

    {:ok,
     %{
       max_concurrency: Application.get_env(:nft_media_handler, :worker_concurrency),
       current_concurrency: 0,
       batch_size: Application.get_env(:nft_media_handler, :worker_batch_size),
       ref_to_batch: %{}
     }}
  end

  @impl true
  def handle_info(
        :spawn_tasks,
        %{
          max_concurrency: max_concurrency,
          current_concurrency: current_concurrency,
          ref_to_batch: tasks_map,
          batch_size: batch_size
        } = state
      )
      when max_concurrency > current_concurrency do
    to_spawn = max_concurrency - current_concurrency

    {urls, node, folder} =
      (batch_size * to_spawn)
      |> NFTMediaHandlerDispatcherInterface.get_urls()

    spawned =
      urls
      |> Enum.chunk_every(batch_size)
      |> Enum.map(&run_task(&1, node, folder))

    Process.send_after(self(), :spawn_tasks, timeout())

    {:noreply,
     %{
       state
       | current_concurrency: current_concurrency + Enum.count(spawned),
         ref_to_batch: Map.merge(tasks_map, Enum.into(spawned, %{}))
     }}
  end

  @impl true
  def handle_info(:spawn_tasks, state) do
    Process.send_after(self(), :spawn_tasks, timeout())
    {:noreply, state}
  end

  @impl true
  def handle_info({ref, _result}, %{current_concurrency: current_concurrency, ref_to_batch: tasks_map} = state) do
    Process.demonitor(ref, [:flush])
    Process.send(self(), :spawn_tasks, [])

    {:noreply, %{state | current_concurrency: current_concurrency - 1, ref_to_batch: Map.drop(tasks_map, [ref])}}
  end

  # shouldn't happen
  @impl true
  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{current_concurrency: current_concurrency, ref_to_batch: tasks_map} = state
      ) do
    {{urls, node}, tasks_map_updated} = Map.pop(tasks_map, ref)

    Logger.error("Failed to fetch and upload urls (#{inspect(urls)}): #{reason}")

    Enum.each(urls, fn url -> NFTMediaHandlerDispatcherInterface.store_result({:down, reason}, url, node) end)

    Process.send(self(), :spawn_tasks, [])

    {:noreply, %{state | current_concurrency: current_concurrency - 1, ref_to_batch: tasks_map_updated}}
  end

  defp run_task(batch, node, folder),
    do:
      {TaskSupervisor.async_nolink(NFTMediaHandler.TaskSupervisor, fn ->
         Enum.map(batch, fn url ->
           try do
             url
             |> NFTMediaHandler.prepare_and_upload_by_url(folder)
             |> NFTMediaHandlerDispatcherInterface.store_result(url, node)
           rescue
             error ->
               Logger.error(
                 "Failed to fetch and upload url (#{url}): #{Exception.format(:error, error, __STACKTRACE__)}"
               )

               NFTMediaHandlerDispatcherInterface.store_result({:error, error}, url, node)
           end
         end)
       end).ref, {batch, node}}

  defp timeout, do: Application.get_env(:nft_media_handler, :worker_spawn_tasks_timeout)
end
