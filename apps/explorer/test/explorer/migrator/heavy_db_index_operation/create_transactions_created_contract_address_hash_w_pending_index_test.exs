defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateTransactionsCreatedContractAddressHashWPendingIndexTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateTransactionsCreatedContractAddressHashWPendingIndex

  describe "Creates heavy index `transactions_created_contract_address_hash_w_pending_index`" do
    setup do
      configuration = Application.get_env(:explorer, HeavyDbIndexOperation)
      Application.put_env(:explorer, HeavyDbIndexOperation, check_interval: 200)

      on_exit(fn ->
        Application.put_env(:explorer, HeavyDbIndexOperation, configuration)
      end)

      :ok
    end

    test "Creates heavy DB index with no dependencies" do
      migration_name = "heavy_indexes_create_transactions_created_contract_address_hash_w_pending_index"
      index_name = "transactions_created_contract_address_hash_w_pending_index"

      assert MigrationStatus.get_status(migration_name) == nil
      assert Helper.db_index_exists_and_valid?(index_name) == %{exists?: false, valid?: nil}

      CreateTransactionsCreatedContractAddressHashWPendingIndex.start_link([])
      Process.sleep(100)

      assert MigrationStatus.get_status(migration_name) == "started"

      Process.sleep(200)

      assert MigrationStatus.get_status(migration_name) == "completed"

      assert Helper.db_index_exists_and_valid?(index_name) == %{exists?: true, valid?: true}

      assert BackgroundMigrations.get_heavy_indexes_create_transactions_created_contract_address_hash_w_pending_index_finished() ==
               true
    end
  end
end
