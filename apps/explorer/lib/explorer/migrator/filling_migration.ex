defmodule Explorer.Migrator.FillingMigration do
  @moduledoc """
    Provides a behaviour and implementation for data migration tasks that fill or update
    fields in existing database entities or migrates data to another storages (e.g.
    multichain search DB)

    This module defines a template for creating migrations that can process entities in
    batches with parallel execution. It implements a GenServer that manages the
    migration lifecycle and automatically saves migration progress regularly.

    Key features:
    - Batch processing with configurable batch size
    - Parallel execution with configurable concurrency
    - State persistence and ability to automatically resume after interruption
    - Integration with Explorer.Chain.Cache.BackgroundMigrations for status tracking

    ## Migration State Management
    The migration's state is persisted in the database as part of the migration status
    record. This allows migrations to resume from their last checkpoint after system
    restarts or interruptions. The state is updated after each successful batch
    processing.

    ## Cache Integration
    The module integrates with Explorer.Chain.Cache.BackgroundMigrations, which
    maintains an in-memory cache of migration completion statuses. This cache is
    crucial for:
    - Quick status checks during application startup
    - Performance-critical operations that need to verify migration completion
    - Avoiding frequent database queries for migration status

    ## Configuration
    Modules using this behaviour can be configured in the application config:

    ```elixir
    config :explorer, MyMigrationModule,
      batch_size: 500,  # Number of entities per batch (default: 500)
      concurrency: 16,  # Number of parallel tasks (default: 4 * schedulers_online)
      timeout: 0        # Delay between batches in ms (default: 0)
    ```

    The migration process will:
    1. Start and check if already completed
    2. Execute pre-migration tasks via `before_start/0`
    3. Process entities in batches using parallel tasks
    4. Checkpoint progress after each batch in the database
    5. Execute post-migration tasks via `on_finish/0`
    6. Update completion status in both database and in-memory cache
  """

  @doc """
    Returns the name of the migration. The name is used to track the migration's status in
    `Explorer.Migrator.MigrationStatus`.
  """
  @callback migration_name :: String.t()

  @doc """
    This callback defines a query to identify unprocessed entities. While defined as a
    callback in the `FillingMigration` behaviour, it is not directly used by the
    behaviour itself. Instead, it is called by `last_unprocessed_identifiers/1` in
    modules implementing `FillingMigration` to build the query for retrieving
    unprocessed entities. The query should not include any LIMIT clauses, as the
    limiting is handled within `last_unprocessed_identifiers/1`.
  """
  @callback unprocessed_data_query :: Ecto.Query.t() | nil

  @doc """
    This callback retrieves the next batch of data for migration processing. It returns
    a list of entity identifiers that have not yet been processed. The number of
    identifiers returned should allow each migration task (limited by `concurrency()`)
    to process no more than `batch_size()` entities.

    The callback is invoked periodically based on the timeout configuration parameter
    specified in the application config for the module implementing the `FillingMigration`
    behaviour. If the timeout is not specified, it defaults to 0.

    ## Parameters
    - `state`: The current state of the migration process.

    ## Returns
    A tuple containing:
    - List of unprocessed entity identifiers
    - Updated state map (or unchanged state if the identifiers did not trigger a state
      change)

    The updated state map is stored in the database as part of the structure that
    tracks the migration process. When the server restarts, the migration will
    resume from the last saved state.
  """
  @callback last_unprocessed_identifiers(map()) :: {[any()], map()}

  @doc """
    This callback performs the migration for a batch of entities. After collecting
    identifiers, the callback processes a batch of size `batch_size()`. A total of
    `concurrency()` callbacks run in parallel as separate tasks, and the system
    waits for all callbacks to complete. Since no timeout is specified for tasks
    invoking this callback, implementations should complete within a reasonable
    time period.

    After all callback tasks finish, the system schedules gathering of the next
    batch of identifiers according to the timeout configuration parameter in the
    application config for modules implementing the `FillingMigration` behaviour.

    ## Parameters
    - `batch`: The list of identifiers to process. While this could theoretically
      be a list of entities, using identifiers is preferred to minimize memory
      usage during migration.

    ## Returns
    N/A
  """
  @callback update_batch([any()]) :: any()

  @doc """
    This callback updates the migration completion status in the cache.

    The callback is invoked in two scenarios:
    - When the migration is already marked as completed during process initialization
    - When the migration finishes processing all entities

    The implementation updates the in-memory cache that tracks migration completion
    status, which is used during application startup and by performance-critical
    operations to quickly determine if specific data migrations have been completed.
    Some migrations may not require cache updates if their completion status does not
    affect system operations.

    ## Returns
    N/A
  """
  @callback update_cache :: any()

  @doc """
    This callback executes custom logic after all migration batches have been processed.

    The callback runs just before the migration is marked as completed in the database.
    Implementing modules can override this callback to perform any final cleanup or
    post-migration tasks. The default implementation returns `:ignore`.

    ## Returns
    - `:ignore` by default
  """
  @callback on_finish :: any()

  @doc """
    This callback executes custom logic when the migration process initializes.

    The callback runs after the migration is marked as "started" but before the first
    batch processing begins. Implementing modules can override this callback to perform
    any necessary setup or pre-migration tasks. The default implementation returns
    `:ignore`.

    ## Returns
    - `:ignore` by default
  """
  @callback before_start :: any()

  defmacro __using__(opts) do
    quote do
      @behaviour Explorer.Migrator.FillingMigration

      use GenServer, restart: :transient

      import Ecto.Query

      alias Explorer.Migrator.MigrationStatus
      alias Explorer.Repo

      @default_batch_size 500

      def start_link(_) do
        GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
      end

      @doc """
        Checks if the current migration has been completed.

        ## Returns
        - `true` if the migration is completed
        - `false` otherwise
      """
      @spec migration_finished? :: boolean()
      def migration_finished? do
        MigrationStatus.get_status(migration_name()) == "completed"
      end

      @impl true
      def init(_) do
        {:ok, %{}, {:continue, :ok}}
      end

      # Called once when the GenServer starts to initialize the migration process by checking its
      # current status and taking appropriate action.
      #
      # If the migration is already completed, updates the in-memory cache and stops normally.
      # Otherwise, marks the migration as started, executes pre-migration tasks via
      # before_start/0, and schedules the first batch with no delay. The migration process
      # continues with the state that was saved during the previous run - this allows
      # resuming long-running migrations from where they were interrupted.
      #
      # ## Parameters
      # - `state`: The current state of the GenServer
      #
      # ## Returns
      # - `{:stop, :normal, state}` if migration is completed
      # - `{:noreply, state}` to continue with migration, where state is restored from the
      #   previous run or initialized as empty map
      @impl true
      def handle_continue(:ok, state) do
        case MigrationStatus.fetch(migration_name()) do
          %{status: "completed"} ->
            update_cache()
            {:stop, :normal, state}

          migration_status ->
            MigrationStatus.set_status(migration_name(), "started")
            before_start()
            schedule_batch_migration(0)
            {:noreply, (migration_status && migration_status.meta) || %{}}
        end
      end

      # Processes a batch of unprocessed identifiers for migration.
      #
      # Retrieves the next batch of unprocessed identifiers and processes them in parallel.
      # If no identifiers remain, executes cleanup tasks and completes the migration.
      # Otherwise, processes the batch and continues migration.
      #
      # When identifiers are found, the function splits them into chunks and processes each
      # chunk by spawning a task that calls update_batch. It waits for all tasks to complete
      # with no timeout limit. After processing, it checkpoints the state to allow using it
      # after restart, then schedules the next batch processing using the configured timeout
      # from the application config (defaults to 0ms if not set).
      #
      # When no more identifiers are found, the function performs final cleanup by calling
      # the optional on_finish callback, refreshes the in-memory cache via update_cache,
      # and marks the migration as completed.
      #
      # ## Parameters
      # - `state`: Current migration state containing progress information
      #
      # ## Returns
      # - `{:stop, :normal, new_state}` when migration is complete
      # - `{:noreply, new_state}` when more batches remain to be processed
      @impl true
      def handle_info(:migrate_batch, state) do
        case last_unprocessed_identifiers(state) do
          {[], new_state} ->
            on_finish()
            update_cache()
            MigrationStatus.set_status(migration_name(), "completed")
            {:stop, :normal, new_state}

          {identifiers, new_state} ->
            identifiers
            |> Enum.chunk_every(batch_size())
            |> Enum.map(&run_task/1)
            |> Task.await_many(:infinity)

            unquote do
              unless opts[:skip_meta_update?] do
                quote do
                  MigrationStatus.update_meta(migration_name(), new_state)
                end
              end
            end

            schedule_batch_migration()

            {:noreply, new_state}
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
      defp schedule_batch_migration(timeout \\ nil) do
        Process.send_after(self(), :migrate_batch, timeout || Application.get_env(:explorer, __MODULE__)[:timeout] || 0)
      end

      defp batch_size do
        Application.get_env(:explorer, __MODULE__)[:batch_size] || @default_batch_size
      end

      defp concurrency do
        default = 4 * System.schedulers_online()

        Application.get_env(:explorer, __MODULE__)[:concurrency] || default
      end

      def on_finish do
        :ignore
      end

      def before_start do
        :ignore
      end

      defoverridable on_finish: 0, before_start: 0
    end
  end
end
