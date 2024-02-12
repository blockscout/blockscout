defmodule Explorer.Migrator.FillingMigration do
  @moduledoc """
  Template for creating migrations that fills some fields in existing entities
  """

  @callback migration_name :: String.t()
  @callback unprocessed_data_query :: Ecto.Query.t()
  @callback last_unprocessed_identifiers :: [any()]
  @callback update_batch([any()]) :: any()
  @callback update_cache :: any()

  defmacro __using__(_opts) do
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

      def migration_finished? do
        MigrationStatus.get_status(migration_name()) == "completed"
      end

      @impl true
      def init(_) do
        case MigrationStatus.get_status(migration_name()) do
          "completed" ->
            update_cache()
            :ignore

          _ ->
            MigrationStatus.set_status(migration_name(), "started")
            schedule_batch_migration()
            {:ok, %{}}
        end
      end

      @impl true
      def handle_info(:migrate_batch, state) do
        case last_unprocessed_identifiers() do
          [] ->
            update_cache()
            MigrationStatus.set_status(migration_name(), "completed")
            {:stop, :normal, state}

          hashes ->
            hashes
            |> Enum.chunk_every(batch_size())
            |> Enum.map(&run_task/1)
            |> Task.await_many(:infinity)

            schedule_batch_migration()

            {:noreply, state}
        end
      end

      defp run_task(batch), do: Task.async(fn -> update_batch(batch) end)

      defp schedule_batch_migration do
        Process.send(self(), :migrate_batch, [])
      end

      defp batch_size do
        Application.get_env(:explorer, __MODULE__)[:batch_size] || @default_batch_size
      end

      defp concurrency do
        default = 4 * System.schedulers_online()

        Application.get_env(:explorer, __MODULE__)[:concurrency] || default
      end
    end
  end
end
