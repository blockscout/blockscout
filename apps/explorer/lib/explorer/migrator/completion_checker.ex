defmodule Explorer.Migrator.CompletionChecker do
  @moduledoc """
  Checks if all necessary migrations are completed at the start of the application
  """

  alias Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockHashTransactionIndexIndexUniqueIndex
  alias Explorer.Migrator.MigrationStatus

  @vital_migrations [CreateInternalTransactionsBlockHashTransactionIndexIndexUniqueIndex]

  def check! do
    if Application.get_env(:explorer, __MODULE__)[:enabled] do
      migration_names = Enum.map(@vital_migrations, fn migration_module -> migration_module.migration_name() end)
      migration_statuses = MigrationStatus.fetch_migration_statuses(migration_names)

      all_migrations_completed? =
        Enum.count(migration_statuses) == Enum.count(@vital_migrations) and
          Enum.all?(migration_statuses, &(&1 == "completed"))

      unless all_migrations_completed? do
        raise "All of these migrations should be completed before #{Application.get_env(:block_scout_web, :version)} release: #{inspect(migration_names)}"
      end
    end
  end
end
