defmodule Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsCreatedContractAddressHashWithPendingIndexATest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateTransactionsCreatedContractAddressHashWPendingIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsCreatedContractAddressHashWithPendingIndexA
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper

  describe "Drops heavy index `transactions_created_contract_address_hash_with_pending_index_a`" do
    setup do
      configuration = Application.get_env(:explorer, HeavyDbIndexOperation)
      Application.put_env(:explorer, HeavyDbIndexOperation, check_interval: 200)

      on_exit(fn ->
        Application.put_env(:explorer, HeavyDbIndexOperation, configuration)
      end)

      :ok
    end

    test "Drops heavy DB index with dependency on create migration" do
      create_migration_name = CreateTransactionsCreatedContractAddressHashWPendingIndex.migration_name()
      drop_migration_name = "heavy_indexes_drop_transactions_created_contract_address_hash_with_pending_index_a"
      index_name = "transactions_created_contract_address_hash_with_pending_index_a"

      assert MigrationStatus.get_status(drop_migration_name) == nil
      assert Helper.db_index_exists_and_valid?(index_name) == %{exists?: true, valid?: true}

      DropTransactionsCreatedContractAddressHashWithPendingIndexA.start_link([])
      Process.sleep(100)

      # Should not start until dependency is completed
      assert MigrationStatus.get_status(drop_migration_name) == nil

      # Mark create migration as completed
      insert(:db_migration_status, migration_name: create_migration_name, status: "completed")

      Process.sleep(150)

      assert MigrationStatus.get_status(drop_migration_name) == "started"

      Process.sleep(200)

      assert MigrationStatus.get_status(drop_migration_name) == "completed"

      assert Helper.db_index_exists_and_valid?(index_name) == %{exists?: false, valid?: nil}

      assert BackgroundMigrations.get_heavy_indexes_drop_transactions_created_contract_address_hash_with_pending_index_a_finished() ==
               true
    end
  end
end
