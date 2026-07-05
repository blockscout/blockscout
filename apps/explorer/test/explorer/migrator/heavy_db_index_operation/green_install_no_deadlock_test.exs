# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.GreenInstallNoDeadlockTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockHashIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.DropLogsBlockNumberAscIndexAscIndex

  describe "Green install: same-table migrations run sequentially without deadlocks" do
    setup do
      configuration = Application.get_env(:explorer, HeavyDbIndexOperation)
      Application.put_env(:explorer, HeavyDbIndexOperation, check_interval: 200)

      on_exit(fn ->
        Application.put_env(:explorer, HeavyDbIndexOperation, configuration)
      end)

      :ok
    end

    test "two migrations on the same table do not run db_index_operation concurrently in init()" do
      # Both migrations operate on the :logs table
      create_migration_name = "heavy_indexes_create_logs_block_hash_index"
      drop_migration_name = "heavy_indexes_drop_logs_block_number_asc__index_asc_index"

      # Ensure clean state: no blocks exist (green install), no migration statuses
      assert MigrationStatus.get_status(create_migration_name) == nil
      assert MigrationStatus.get_status(drop_migration_name) == nil

      # Start both migrations simultaneously (simulating application boot)
      CreateLogsBlockHashIndex.start_link([])
      DropLogsBlockNumberAscIndexAscIndex.start_link([])

      # Wait for the async polling cycle to process
      Process.sleep(500)

      # Both should eventually complete without deadlock errors
      # The key assertion: neither migration crashed, both reached a valid state
      create_status = MigrationStatus.get_status(create_migration_name)
      drop_status = MigrationStatus.get_status(drop_migration_name)

      # At least one should be completed (the one that ran first in init())
      # The other may be "started" or "completed" depending on timing
      completed_count =
        Enum.count([create_status, drop_status], fn status -> status == "completed" end)

      started_count =
        Enum.count([create_status, drop_status], fn status -> status == "started" end)

      # Both migrations should be in a valid non-error state
      assert completed_count + started_count == 2

      # Verify the create index exists and is valid
      create_index_name = "logs_block_hash_index"
      assert Helper.db_index_exists_and_valid?(create_index_name) == %{exists?: true, valid?: true}

      # Verify the drop index no longer exists
      drop_index_name = "logs_block_number_ASC_index_ASC_index"
      drop_index_status = Helper.db_index_exists_and_valid?(drop_index_name)
      assert drop_index_status == %{exists?: false, valid?: nil}
    end

    test "migration with unmet dependencies defers to async path on green install" do
      migration_name = "heavy_indexes_create_logs_address_hash_block_number_desc_index_desc_index"
      index_name = "logs_address_hash_block_number_DESC_index_DESC_index"

      assert MigrationStatus.get_status(migration_name) == nil

      # Start migration without its dependencies being completed
      Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressHashBlockNumberDescIndexDescIndex.start_link([])
      Process.sleep(100)

      # On green install with unmet deps, it should NOT run db_index_operation in init()
      # Status should remain nil (not "completed" and not "started" yet)
      assert MigrationStatus.get_status(migration_name) == nil

      # Now mark dependencies as completed
      insert(:db_migration_status,
        migration_name: "heavy_indexes_drop_logs_block_number_asc__index_asc_index",
        status: "completed"
      )

      insert(:db_migration_status, migration_name: "heavy_indexes_create_logs_block_hash_index", status: "completed")

      # Wait for polling cycle to pick up the completed deps
      Process.sleep(500)

      assert MigrationStatus.get_status(migration_name) == "completed"
      assert Helper.db_index_exists_and_valid?(index_name) == %{exists?: true, valid?: true}
    end
  end
end