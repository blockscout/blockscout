defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressHashBlockNumberDescIndexDescIndexTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressHashBlockNumberDescIndexDescIndex

  describe "Creates heavy index `logs_address_hash_block_number_DESC_index_DESC_index`" do
    setup do
      configuration = Application.get_env(:explorer, HeavyDbIndexOperation)
      Application.put_env(:explorer, HeavyDbIndexOperation, check_interval: 200)

      on_exit(fn ->
        Application.put_env(:explorer, HeavyDbIndexOperation, configuration)
      end)

      :ok
    end

    test "Creates heavy DB index with dependencies" do
      migration_name = "heavy_indexes_create_logs_address_hash_block_number_desc_index_desc_index"
      index_name = "logs_address_hash_block_number_DESC_index_DESC_index"

      assert MigrationStatus.get_status(migration_name) == nil
      assert Helper.db_index_exists_and_valid?(index_name) == %{exists?: false, valid?: nil}

      CreateLogsAddressHashBlockNumberDescIndexDescIndex.start_link([])
      Process.sleep(100)

      assert MigrationStatus.get_status(migration_name) == nil

      insert(:db_migration_status,
        migration_name: "heavy_indexes_drop_logs_block_number_asc__index_asc_index",
        status: "completed"
      )

      insert(:db_migration_status, migration_name: "heavy_indexes_create_logs_block_hash_index", status: "completed")

      Process.sleep(150)

      assert MigrationStatus.get_status(migration_name) == "started"

      Process.sleep(200)

      assert MigrationStatus.get_status(migration_name) == "completed"

      assert Helper.db_index_exists_and_valid?(index_name) == %{exists?: true, valid?: true}

      assert BackgroundMigrations.get_heavy_indexes_create_logs_address_hash_block_number_desc_index_desc_index_finished() ==
               true
    end
  end
end
