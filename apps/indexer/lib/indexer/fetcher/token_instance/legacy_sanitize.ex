defmodule Indexer.Fetcher.TokenInstance.LegacySanitize do
  @moduledoc """
    This fetcher is stands for creating token instances which wasn't inserted yet and index meta for them.
    Legacy is because now we token instances inserted on block import and this fetcher is only for historical and unfetched for some reasons data
  """

  use GenServer, restart: :transient

  alias Explorer.Chain.Token.Instance
  alias Explorer.Repo

  import Indexer.Fetcher.TokenInstance.Helper

  def start_link(_) do
    concurrency = Application.get_env(:indexer, __MODULE__)[:concurrency]
    batch_size = Application.get_env(:indexer, __MODULE__)[:batch_size]
    GenServer.start_link(__MODULE__, %{concurrency: concurrency, batch_size: batch_size}, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    GenServer.cast(__MODULE__, :backfill)

    {:ok, opts}
  end

  @impl true
  def handle_cast(:backfill, %{concurrency: concurrency, batch_size: batch_size} = state) do
    instances_to_fetch =
      (concurrency * batch_size)
      |> Instance.not_inserted_token_instances_query()
      |> Repo.all()

    if Enum.empty?(instances_to_fetch) do
      {:stop, :normal, state}
    else
      instances_to_fetch
      |> Enum.uniq()
      |> Enum.chunk_every(batch_size)
      |> Enum.map(&process_batch/1)
      |> Task.await_many(:infinity)

      GenServer.cast(__MODULE__, :backfill)

      {:noreply, state}
    end
  end

  defp process_batch(batch), do: Task.async(fn -> batch_fetch_instances(batch) end)
end
