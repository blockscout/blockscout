defmodule Indexer.Fetcher.TokenInstance.SanitizeERC721 do
  @moduledoc """
    This fetcher is stands for creating token instances which wasn't inserted yet and index meta for them.

    !!!Imports only ERC-721 token instances!!!
  """

  use GenServer, restart: :transient

  alias Explorer.Application.Constants
  alias Explorer.Chain.Token
  alias Explorer.Chain.Token.Instance
  alias Explorer.Migrator.MigrationStatus
  alias Explorer.Repo
  alias Explorer.TokenInstanceOwnerAddressMigration.Helper, as: TokenInstanceOwnerAddressMigrationHelper
  alias Indexer.Fetcher.TokenInstance.Sanitize

  @migration_name "backfill_erc721"

  def start_link(_) do
    concurrency = Application.get_env(:indexer, __MODULE__)[:concurrency]
    batch_size = Application.get_env(:indexer, __MODULE__)[:batch_size]
    tokens_queue_size = Application.get_env(:indexer, __MODULE__)[:tokens_queue_size]

    GenServer.start_link(
      __MODULE__,
      %{concurrency: concurrency, batch_size: batch_size, tokens_queue_size: tokens_queue_size},
      name: __MODULE__
    )
  end

  @impl true
  def init(opts) do
    {:ok, %{}, {:continue, opts}}
  end

  @impl true
  def handle_continue(opts, state) do
    case MigrationStatus.get_status(@migration_name) do
      "completed" ->
        {:stop, :normal, state}

      _ ->
        MigrationStatus.set_status(@migration_name, "started")
        last_token_address_hash = Constants.get_last_processed_token_address_hash()
        GenServer.cast(__MODULE__, :fetch_tokens_queue)

        {:noreply, Map.put(opts, :last_token_address_hash, last_token_address_hash)}
    end
  end

  @impl true
  def handle_cast(:fetch_tokens_queue, state) do
    address_hashes =
      state[:tokens_queue_size]
      |> Token.ordered_erc_721_token_address_hashes_list_query(state[:last_token_address_hash])
      |> Repo.all()

    if Enum.empty?(address_hashes) do
      MigrationStatus.set_status(@migration_name, "completed")
      {:stop, :normal, state}
    else
      GenServer.cast(__MODULE__, :backfill)

      {:noreply, Map.put(state, :tokens_queue, address_hashes)}
    end
  end

  @impl true
  def handle_cast(:backfill, %{tokens_queue: []} = state) do
    GenServer.cast(__MODULE__, :fetch_tokens_queue)

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        :backfill,
        %{concurrency: concurrency, batch_size: batch_size, tokens_queue: [current_address_hash | remains]} = state
      ) do
    instances_to_fetch =
      (concurrency * batch_size)
      |> Instance.not_inserted_token_instances_query_by_token(current_address_hash)
      |> Repo.all()

    if Enum.empty?(instances_to_fetch) do
      Constants.insert_last_processed_token_address_hash(current_address_hash)
      GenServer.cast(__MODULE__, :backfill)

      {:noreply, %{state | tokens_queue: remains, last_token_address_hash: current_address_hash}}
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

  defp process_batch(batch), do: Task.async(fn -> TokenInstanceOwnerAddressMigrationHelper.fetch_and_insert(batch) end)
end
