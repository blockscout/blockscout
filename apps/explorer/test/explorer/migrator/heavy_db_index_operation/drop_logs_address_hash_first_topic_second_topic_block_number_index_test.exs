# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndexTest do
  use Explorer.DataCase, async: false

  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper
  alias Explorer.Repo

  @index_name "logs_address_hash_first_topic_second_topic_block_number_index"

  describe "Drops heavy index `#{@index_name}`" do
    setup do
      configuration = Application.get_env(:explorer, HeavyDbIndexOperation)
      Application.put_env(:explorer, HeavyDbIndexOperation, Keyword.merge(configuration || [], check_interval: 200))

      # The index is created by a heavy migration, not by an Ecto migration, so it is absent from the test schema.
      Repo.query!(
        "CREATE INDEX IF NOT EXISTS \"#{@index_name}\" ON logs (address_hash, first_topic, second_topic, block_number, index)"
      )

      on_exit(fn ->
        Application.put_env(:explorer, HeavyDbIndexOperation, configuration)
      end)

      :ok
    end

    test "Drops heavy DB index only after all dependent migrations are completed" do
      migration_name = DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.migration_name()
      dependent_migration_names = DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.dependent_from_migrations()

      assert length(dependent_migration_names) == 3
      assert MigrationStatus.get_status(migration_name) == nil
      assert Helper.db_index_exists_and_valid?(@index_name) == %{exists?: true, valid?: true}

      DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.start_link([])
      Process.sleep(300)

      # Should not start until all dependencies are completed
      assert MigrationStatus.get_status(migration_name) == nil
      assert Helper.db_index_exists_and_valid?(@index_name) == %{exists?: true, valid?: true}

      Enum.each(dependent_migration_names, fn dependent_migration_name ->
        insert(:db_migration_status, migration_name: dependent_migration_name, status: "completed")
      end)

      Process.sleep(300)

      assert MigrationStatus.get_status(migration_name) == "completed"
      assert Helper.db_index_exists_and_valid?(@index_name) == %{exists?: false, valid?: nil}
    end
  end
end
