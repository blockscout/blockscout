# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation do
  @moduledoc """
  Provides a template for making heavy DB operations such as creation/deletion of new indexes in the large tables
  with tracking status of those migrations.

  ## Default callback implementations

  Modules that `use` this behaviour only have to declare a few module attributes; the
  callbacks that are the same for every plain index creation/deletion are generated at
  compile time by `__before_compile__/1` unless the module defines them itself:

  - `table_name/0`, `operation_type/0`, `index_name/0` return `@table_name`,
    `@operation_type` and `@index_name` respectively.
  - `dependent_from_migrations/0` returns `[]`.
  - `update_cache/0` is a no-op.
  - `running_other_heavy_migration_exists?/1` checks `Explorer.Migrator.MigrationStatus`
    for other heavy migrations on `@table_name`.
  - `db_index_operation/0`, `check_db_index_operation_progress/0`,
    `db_index_operation_status/0` and `restart_db_index_operation/0` are generated for
    `:create` operations that declare either `@query_string` or `@table_columns`
    (optionally with `@unique_index true`), and for `:drop` operations. `:rename`
    operations and any other custom operation must implement them explicitly.
  """

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper
  alias Explorer.Migrator.MigrationStatus

  @doc """
  Returns the name of the migration. The name is used to track the operation's status in
  `Explorer.Migrator.MigrationStatus`.
  Heavy DB migration is either `heavy_indexes_create_{lower_case_index_name}`, `heavy_indexes_drop_{lower_case_index_name}`, or `heavy_indexes_rename_{lower_case_index_name}`
  """
  @callback migration_name :: String.t()

  @doc """
  Returns the name of the table on which the index operation will be performed.

  The name is used to track the operation's status in `Explorer.Migrator.MigrationStatus`.

  It's explicitly defined as a specific atom to ensure type safety. This helps
  prevent typos or errors when creating migrations, as dialyzer will raise an
  error if an invalid table name is used.

  If you need to add a new table, extend this type specification with the new table name.
  """
  @callback table_name ::
              :transactions
              | :logs
              | :internal_transactions
              | :token_transfers
              | :token_instances
              | :addresses
              | :smart_contracts
              | :arbitrum_batch_l2_blocks
              | :smart_contracts_additional_sources
              | :tokens
              | :address_current_token_balances
              | :address_token_balances
              | :deleted_internal_transactions_address_placeholders
  @doc """
  Specifies the type of operation to be performed on the database index.

  ## Returns
  - `:create` - Indicates that the operation is to add a new index.
  - `:drop` - Indicates that the operation is to drop an existing index.
  - `:rename` - Indicates that the operation is to rename an existing index.
  """
  @callback operation_type :: :create | :drop | :rename

  @doc """
  Returns the name of the index as a string.
  """
  @callback index_name :: String.t()

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
    - `:in_progress` - Indicates that the operation is currently in progress. The optional string provides additional information about the progress.
    - `:unknown` - Indicates that the status of the operation is unknown.
  """
  @callback check_db_index_operation_progress() ::
              :finished_or_not_started | :unknown | :in_progress

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
  Checks if there is any heavy migration (except current migration) currently running for the given table.

  ## Returns

    - `true` if a heavy migration is running.
    - `false` otherwise.
  """
  @callback running_other_heavy_migration_exists?(String.t()) :: boolean()

  @doc """
  This callback restarts initial index operation once its completion is failed, e.g. index is invalid after creation.
  """
  @callback restart_db_index_operation() :: :ok | :error

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
    # credo:disable-for-next-line
    quote do
      @behaviour Explorer.Migrator.HeavyDbIndexOperation
      @before_compile Explorer.Migrator.HeavyDbIndexOperation

      use GenServer, restart: :transient

      import Ecto.Query

      alias Ecto.Adapters.SQL
      alias Explorer.Chain.Block
      alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper
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
        with {:green_install?, true} <- {:green_install?, not Repo.exists?(Block)},
             {:migration_finished?, false} <- {:migration_finished?, migration_finished?()},
             {:dependent_from_migrations_completed?, true} <-
               {:dependent_from_migrations_completed?, dependent_from_migrations_completed?()},
             {:db_index_operation, :ok} <- {:db_index_operation, db_index_operation()} do
          MigrationStatus.set_status(migration_name(), "completed")
          update_cache()
          :ignore
        else
          {:migration_finished?, true} ->
            update_cache()
            :ignore

          _ ->
            {:ok, %{}, {:continue, :ok}}
        end
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
            Process.send(self(), :check_db_index_operation_progress, [])
            {:noreply, state}
        end
      end

      @impl true
      def handle_info(:check_db_index_operation_progress, state) do
        with {:index_operation_progress, status} when status in [:finished_or_not_started, :finished] <-
               {:index_operation_progress, check_db_index_operation_progress()},
             {:db_index_operation_status, :not_initialized} <-
               {:db_index_operation_status, db_index_operation_status()} do
          if db_operation_is_ready_to_start?() do
            MigrationStatus.set_status(migration_name(), "started")
            timeout = (db_index_operation() == :ok && 0) || nil
            schedule_next_db_operation_status_check(timeout)
          else
            schedule_next_db_operation_readiness_check()
          end

          {:noreply, state}
        else
          {:index_operation_progress, _status} ->
            schedule_next_db_operation_status_check()
            {:noreply, state}

          {:db_index_operation_status, :not_completed} ->
            Process.send(self(), :restart_db_index_operation, [])
            {:noreply, state}

          {:db_index_operation_status, :unknown} ->
            schedule_next_db_operation_status_check()
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

          :error ->
            schedule_next_db_index_operation_completion_check()
        end

        {:noreply, state}
      end

      defp db_operation_is_ready_to_start? do
        if running_other_heavy_migration_exists?(migration_name()) do
          false
        else
          dependent_from_migrations_completed?()
        end
      end

      defp dependent_from_migrations_completed? do
        if Enum.empty?(dependent_from_migrations()) do
          true
        else
          all_statuses =
            MigrationStatus.fetch_migration_statuses(dependent_from_migrations())

          all_statuses_completed? = not Enum.empty?(all_statuses) && all_statuses |> Enum.all?(&(&1 == "completed"))

          all_statuses_completed? && Enum.count(all_statuses) == Enum.count(dependent_from_migrations())
        end
      end

      defp schedule_next_db_operation_status_check(timeout \\ nil) do
        Process.send_after(
          self(),
          :check_db_index_operation_progress,
          timeout || HeavyDbIndexOperationHelper.get_check_interval()
        )
      end

      defp schedule_next_db_operation_readiness_check(timeout \\ nil) do
        Process.send_after(
          self(),
          :check_db_index_operation_progress,
          timeout || HeavyDbIndexOperationHelper.get_check_interval()
        )
      end

      defp schedule_next_db_index_operation_completion_check(timeout \\ nil) do
        Process.send_after(
          self(),
          :restart_db_index_operation,
          timeout || :timer.seconds(10)
        )
      end

      @impl Explorer.Migrator.HeavyDbIndexOperation
      def migration_name do
        index_name_lower_case = String.downcase(index_name())

        db_operation_prefix =
          "#{HeavyDbIndexOperationHelper.heavy_db_operation_migration_name_prefix()}#{to_string(operation_type())}"

        "#{db_operation_prefix}_#{index_name_lower_case}"
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    module = env.module

    {:__block__, [], default_getters(module) ++ default_index_operation_callbacks(module)}
  end

  # Generates the callbacks which only return module attributes or constants,
  # unless the module defines them itself.
  defp default_getters(module) do
    defaults = [
      {:table_name, 0, quote(do: def(table_name, do: @table_name))},
      {:operation_type, 0, quote(do: def(operation_type, do: @operation_type))},
      {:index_name, 0, quote(do: def(index_name, do: @index_name))},
      {:dependent_from_migrations, 0, quote(do: def(dependent_from_migrations, do: []))},
      {:update_cache, 0, quote(do: def(update_cache, do: :ok))},
      {:running_other_heavy_migration_exists?, 1,
       quote do
         def running_other_heavy_migration_exists?(migration_name) do
           MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
         end
       end}
    ]

    for {name, arity, definition} <- defaults, not Module.defines?(module, {name, arity}) do
      quote do
        @impl Explorer.Migrator.HeavyDbIndexOperation
        unquote(definition)
      end
    end
  end

  # Generates the callbacks performing the index operation itself for plain
  # `:create` and `:drop` operations, unless the module defines them itself.
  defp default_index_operation_callbacks(module) do
    operation_type = Module.get_attribute(module, :operation_type)
    query_string? = Module.has_attribute?(module, :query_string)
    table_columns? = Module.has_attribute?(module, :table_columns)
    unique? = Module.get_attribute(module, :unique_index) == true

    case {operation_type, query_string?, table_columns?} do
      {:create, true, _} ->
        create_index_callbacks(module, quote(do: @query_string))

      {:create, false, true} ->
        create_index_callbacks(
          module,
          quote do
            Helper.create_index_query_string(@index_name, @table_name, @table_columns, unquote(unique?))
          end
        )

      {:drop, _, _} ->
        drop_index_callbacks(module)

      _ ->
        []
    end
  end

  defp create_index_callbacks(module, query_string_ast) do
    defaults = [
      {:db_index_operation, 0,
       quote do
         def db_index_operation do
           Helper.create_db_index(unquote(query_string_ast))
         end
       end},
      {:check_db_index_operation_progress, 0,
       quote do
         def check_db_index_operation_progress do
           Helper.check_db_index_operation_progress(@index_name, unquote(query_string_ast))
         end
       end},
      {:db_index_operation_status, 0,
       quote do
         def db_index_operation_status do
           Helper.db_index_creation_status(@index_name)
         end
       end},
      {:restart_db_index_operation, 0,
       quote do
         def restart_db_index_operation do
           Helper.safely_drop_db_index(@index_name)
         end
       end}
    ]

    emit_undefined(module, defaults)
  end

  defp drop_index_callbacks(module) do
    defaults = [
      {:db_index_operation, 0,
       quote do
         def db_index_operation do
           Helper.safely_drop_db_index(@index_name)
         end
       end},
      {:check_db_index_operation_progress, 0,
       quote do
         def check_db_index_operation_progress do
           operation = Helper.drop_index_query_string(@index_name)
           Helper.check_db_index_operation_progress(@index_name, operation)
         end
       end},
      {:db_index_operation_status, 0,
       quote do
         def db_index_operation_status do
           Helper.db_index_dropping_status(@index_name)
         end
       end},
      {:restart_db_index_operation, 0,
       quote do
         def restart_db_index_operation do
           Helper.safely_drop_db_index(@index_name)
         end
       end}
    ]

    emit_undefined(module, defaults)
  end

  defp emit_undefined(module, defaults) do
    for {name, arity, definition} <- defaults, not Module.defines?(module, {name, arity}) do
      quote do
        @impl Explorer.Migrator.HeavyDbIndexOperation
        unquote(definition)
      end
    end
  end
end
