defmodule Explorer.Migrator.SanitizeVerifiedAddresses do
  @moduledoc """
  Sets `verified` field to `true` for all addresses that have a corresponding
  entry in `smart_contracts` table.

  NOTE: This migrator runs on every application start. The migration (re)starts
  if any unprocessed data appeared (or still present) in the database.
  """

  use GenServer, restart: :transient

  import Ecto.Query

  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Repo

  def unprocessed_data_query do
    from(address in Address,
      join: smart_contract in SmartContract,
      on: address.hash == smart_contract.address_hash,
      where: address.verified == false or is_nil(address.verified)
    )
  end

  def last_unprocessed_identifiers do
    limit = batch_size() * concurrency()

    unprocessed_data_query()
    |> select([a], a.hash)
    |> limit(^limit)
    |> Repo.all(timeout: :infinity)
  end

  def update_batch(address_hashes) do
    query =
      from(address in Address,
        where: address.hash in ^address_hashes,
        update: [set: [verified: true]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :ok}}
  end

  # Called once when the GenServer starts to initialize the migration process by
  # checking its current status and taking appropriate action.
  #
  # ## Parameters
  # - `state`: The current state of the GenServer
  #
  # ## Returns
  # - `{:stop, :normal, state}` if migration is completed
  # - `{:noreply, state}` to continue with migration, where state is restored
  #   from the previous run or initialized as empty map
  @impl true
  def handle_continue(:ok, state) do
    should_start? = unprocessed_data_query() |> Repo.exists?()

    if should_start? do
      schedule_batch_migration(0)
      {:noreply, %{}}
    else
      update_cache()
      {:stop, :normal, state}
    end
  end

  # Processes a batch of unprocessed identifiers for migration.
  #
  # Retrieves the next batch of unprocessed identifiers and processes them in
  # parallel. If no identifiers remain, completes the migration. Otherwise,
  # processes the batch and continues migration.
  #
  # When identifiers are found, the function splits them into chunks and
  # processes each chunk by spawning a task that calls update_batch. It waits
  # for all tasks to complete with no timeout limit. After processing, it
  # checkpoints the state to allow using it after restart, then schedules the
  # next batch processing using the configured timeout from the application
  # config (defaults to 0ms if not set).
  #
  # When no more identifiers are found, the process is simply stopped.
  #
  # ## Parameters
  # - `state`: Current migration state containing progress information
  #
  # ## Returns
  # - `{:stop, :normal, new_state}` when migration is complete
  # - `{:noreply, new_state}` when more batches remain to be processed
  @impl true
  def handle_info(:migrate_batch, _state) do
    case last_unprocessed_identifiers() do
      [] ->
        update_cache()
        {:stop, :normal, %{}}

      identifiers ->
        identifiers
        |> Enum.chunk_every(batch_size())
        |> Enum.map(&run_task/1)
        |> Task.await_many(:infinity)

        schedule_batch_migration()

        {:noreply, %{}}
    end
  end

  @spec run_task([any()]) :: any()
  defp run_task(batch), do: Task.async(fn -> update_batch(batch) end)

  # Schedules the next batch migration by sending a delayed :migrate_batch message.
  #
  # ## Parameters
  # - `timeout`: Optional delay in milliseconds before sending the message. If nil,
  #   uses the configured timeout from application config, defaulting to 0.
  #
  # ## Returns
  # - Reference to the scheduled timer
  @spec schedule_batch_migration(timeout :: non_neg_integer | nil) :: reference()
  defp schedule_batch_migration(timeout \\ nil) do
    Process.send_after(
      self(),
      :migrate_batch,
      timeout || Application.get_env(:explorer, __MODULE__)[:timeout]
    )
  end

  @spec update_cache() :: :ok
  defp update_cache do
    BackgroundMigrations.set_sanitize_verified_addresses_finished(true)
  end

  @spec batch_size() :: non_neg_integer()
  defp batch_size do
    Application.get_env(:explorer, __MODULE__)[:batch_size]
  end

  @spec concurrency() :: non_neg_integer()
  defp concurrency do
    Application.get_env(:explorer, __MODULE__)[:concurrency]
  end
end
