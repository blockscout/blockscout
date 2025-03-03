defmodule Explorer.Migrator.DropLogsBlockNumberAscIndexAscIndexTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper
  alias Explorer.Migrator.HeavyDbIndexOperation.DropLogsBlockNumberAscIndexAscIndex

  describe "Drops heavy index `logs_block_number_ASC__index_ASC_index`" do
    setup do
      configuration = Application.get_env(:explorer, HeavyDbIndexOperation)
      Application.put_env(:explorer, HeavyDbIndexOperation, check_interval: 200)

      on_exit(fn ->
        Application.put_env(:explorer, HeavyDbIndexOperation, configuration)
      end)

      :ok
    end

    test "Drops heavy DB index with no dependencies" do
      migration_name = "heavy_indexes_drop_logs_block_number_asc__index_asc_index"
      index_name = "logs_block_number_ASC__index_ASC_index"

      assert MigrationStatus.get_status(migration_name) == nil
      assert Helper.db_index_exists_and_valid?(index_name) == %{exists?: true, valid?: true}

      DropLogsBlockNumberAscIndexAscIndex.start_link([])
      Process.sleep(100)

      assert MigrationStatus.get_status(migration_name) == "started"

      Process.sleep(200)

      assert MigrationStatus.get_status(migration_name) == "completed"

      assert Helper.db_index_exists_and_valid?(index_name) == %{exists?: false, valid?: nil}

      assert BackgroundMigrations.get_heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished() ==
               true
    end
  end
end
