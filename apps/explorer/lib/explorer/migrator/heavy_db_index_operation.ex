defmodule Explorer.Migrator.HeavyDbIndexOperation do
  @moduledoc """
  Provides a template for making heavy DB operations such as creation/deletion of new indexes in the large tables
  with tracking status of those migrations.
  """

  @doc """
  Returns the name of the migration. The name is used to track the operation's status in
  `Explorer.Migrator.MigrationStatus`.
  """
  @callback migration_name :: String.t()

  @doc """
  Returns a list of migration names that the current migration depends on.
  """
  @callback dependent_from_migrations :: list(String.t())

  @doc """
  Defines a callback for performing a database index operation.

  ## Returns
  - `:ok` if the operation is successful.
  - `:error` if the operation fails.
  """
  @callback db_index_operation :: :ok | :error

  @doc """
  Checks the progress of a database index operation.

  ## Return Values

    - `:finished_or_not_started` - Indicates that the operation is either finished or has not started.
    - `:unknown` - Indicates that the status of the operation is unknown.
    - `{:in_progress, String.t() | nil}` - Indicates that the operation is currently in progress. The optional string provides additional information about the progress.

  ## Examples

      iex> check_db_index_operation_progress()
      :finished_or_not_started

      iex> check_db_index_operation_progress()
      :unknown

      iex> check_db_index_operation_progress()
      {:in_progress, "50% completed"}
  """
  @callback check_db_index_operation_progress() ::
              :finished_or_not_started | :unknown | {:in_progress, String.t() | nil}

  @doc """
  Returns the current status of the database index operation.

  ## Returns

    - `:not_initialized` - The database index operation has not been initialized.
    - `:not_completed` - The database index operation has been initialized but not completed.
    - `:completed` - The database index operation has been completed.
    - `:unknown` - The status of the database index operation is unknown.
  """
  @callback db_index_operation_status() :: :not_initialized | :not_completed | :completed | :unknown

  @doc """
  This callback restarts initial index operation once its completion is failed, e.g. index is invalid after creation.
  """
  @callback restart_db_index_operation() :: :ok | :error | :not_applicable

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

  defmacro __using__(_opts) do
    quote do
      @behaviour Explorer.Migrator.HeavyDbIndexOperation

      use GenServer, restart: :transient

      import Ecto.Query

      alias Ecto.Adapters.SQL
      alias Explorer.Migrator.MigrationStatus
      alias Explorer.Repo

      def start_link(_) do
        GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
      end

      @doc """
       Checks if the migration has been completed.

       ## Returns
       - `true` if the migration status is `"completed"`.
       - `false` otherwise.
      """
      @spec migration_finished? :: boolean()
      def migration_finished? do
        MigrationStatus.get_status(migration_name()) == "completed"
      end

      @impl true
      def init(_) do
        {:ok, %{}, {:continue, :ok}}
      end

      @impl true
      def handle_continue(:ok, state) do
        Process.send(self(), :initiate_index_operation, [])
        {:noreply, state}
      end

      @impl true
      def handle_info(:initiate_index_operation, state) do
        case MigrationStatus.fetch(migration_name()) do
          %{status: "completed"} ->
            update_cache()
            {:stop, :normal, state}

          migration_status ->
            Process.send(self(), :check_if_db_operation_need_to_be_started, [])
            {:noreply, state}
        end
      end

      @impl true
      def handle_info(:check_if_db_operation_need_to_be_started, state) do
        if db_operation_is_ready_to_start?() do
          Process.send(self(), :check_db_index_operation_progress, [])
        else
          schedule_next_db_operation_readiness_check()
        end

        {:noreply, state}
      end

      @impl true
      def handle_info(:check_db_index_operation_progress, state) do
        with {:index_operation_progress, status} when status in [:finished_or_not_started, :finished] <-
               {:index_operation_progress, check_db_index_operation_progress()},
             {:db_index_operation_status, :not_initialized} <-
               {:db_index_operation_status, db_index_operation_status()} do
          MigrationStatus.set_status(migration_name(), "started")
          db_index_operation()
          schedule_next_db_operation_status_check()
          {:noreply, state}
        else
          {:index_operation_progress, _status} ->
            schedule_next_db_operation_status_check()
            {:noreply, state}

          {:db_index_operation_status, :not_completed} ->
            Process.send(self(), :restart_db_index_operation, [])
            {:noreply, state}

          {:db_index_operation_status, :completed} ->
            MigrationStatus.set_status(migration_name(), "completed")
            update_cache()
            {:stop, :normal, state}
        end
      end

      @impl true
      def handle_info(:restart_db_index_operation, state) do
        case restart_db_index_operation() do
          :ok ->
            Process.send(self(), :initiate_index_operation, [])

          status when status in [:error, :not_applicable] ->
            schedule_next_db_index_operation_completion_check()
        end

        {:noreply, state}
      end

      defp db_operation_is_ready_to_start? do
        if Enum.empty?(dependent_from_migrations()) do
          not MigrationStatus.running_heavy_migration_exists?()
        else
          all_statuses =
            MigrationStatus.get_migrations_status(dependent_from_migrations())

          all_statuses_completed? =
            all_statuses
            |> Enum.all?(&(&1 == "completed"))

          all_statuses_completed? && Enum.count(all_statuses) == Enum.count(dependent_from_migrations())
        end
      end

      defp schedule_next_db_operation_status_check(timeout \\ nil) do
        Process.send_after(
          self(),
          :check_db_index_operation_progress,
          timeout || Application.get_env(:explorer, Explorer.Migrator.HeavyDbIndexOperation)[:check_interval] ||
            :timer.minutes(10)
        )
      end

      defp schedule_next_db_operation_readiness_check(timeout \\ nil) do
        Process.send_after(
          self(),
          :check_if_db_operation_need_to_be_started,
          timeout || Application.get_env(:explorer, Explorer.Migrator.HeavyDbIndexOperation)[:check_interval] ||
            :timer.minutes(10)
        )
      end

      defp schedule_next_db_index_operation_completion_check(timeout \\ nil) do
        Process.send_after(
          self(),
          :restart_db_index_operation,
          timeout || :timer.seconds(10)
        )
      end
    end
  end
end
