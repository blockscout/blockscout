defmodule Indexer.Fetcher.TokenInstance.SanitizeERC1155 do
  @moduledoc """
    This fetcher is stands for creating token instances which wasn't inserted yet and index meta for them.

    !!!Imports only ERC-1155 token instances!!!
  """

  use GenServer, restart: :transient

  alias Explorer.Chain.Token.Instance
  alias Explorer.Migrator.MigrationStatus
  alias Explorer.{Chain, Repo}
  alias Indexer.Fetcher.TokenInstance.Sanitize

  @migration_name "backfill_erc1155"

  def start_link(_) do
    concurrency = Application.get_env(:indexer, __MODULE__)[:concurrency]
    batch_size = Application.get_env(:indexer, __MODULE__)[:batch_size]
    GenServer.start_link(__MODULE__, %{concurrency: concurrency, batch_size: batch_size}, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok, opts, {:continue, :ok}}
  end

  @impl true
  def handle_continue(:ok, state) do
    case MigrationStatus.get_status(@migration_name) do
      "completed" ->
        {:stop, :normal, state}

      _ ->
        MigrationStatus.set_status(@migration_name, "started")
        GenServer.cast(__MODULE__, :backfill)
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:backfill, %{concurrency: concurrency, batch_size: batch_size} = state) do
    instances_to_fetch =
      (concurrency * batch_size)
      |> Instance.not_inserted_erc_1155_token_instances()
      |> Repo.all()

    if Enum.empty?(instances_to_fetch) do
      MigrationStatus.set_status(@migration_name, "completed")
      {:stop, :normal, state}
    else
      uniq_instances =
        instances_to_fetch
        |> Enum.uniq()

      uniq_instances
      |> Enum.chunk_every(batch_size)
      |> Enum.map(&process_batch/1)
      |> Task.await_many(:infinity)

      Sanitize.async_fetch(uniq_instances)

      GenServer.cast(__MODULE__, :backfill)

      {:noreply, state}
    end
  end

  defp process_batch(batch), do: Task.async(fn -> Chain.import(%{token_instances: %{params: batch}}) end)
end
