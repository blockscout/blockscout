# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndexTest do
  use Explorer.DataCase, async: false

  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateLogsAddressHashFirstTopicSecondTopicBlockNumberIndex,
    DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex,
    Helper
  }

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

    test "Drops heavy DB index only after all dependent migrations, including its own create migration, are completed" do
      migration_name = DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.migration_name()
      create_migration_name = CreateLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.migration_name()
      dependent_migration_names = DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.dependent_from_migrations()

      assert length(dependent_migration_names) == 4
      assert create_migration_name in dependent_migration_names
      assert MigrationStatus.get_status(migration_name) == nil
      assert Helper.db_index_exists_and_valid?(@index_name) == %{exists?: true, valid?: true}

      DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.start_link([])
      Process.sleep(300)

      # Should not start until all dependencies are completed
      assert MigrationStatus.get_status(migration_name) == nil
      assert Helper.db_index_exists_and_valid?(@index_name) == %{exists?: true, valid?: true}

      # Everything except the create migration of this index is completed: emulates the index creation still
      # pending or being retried after a failed build. The drop must keep waiting.
      dependent_migration_names
      |> Enum.reject(&(&1 == create_migration_name))
      |> Enum.each(fn dependent_migration_name ->
        insert(:db_migration_status, migration_name: dependent_migration_name, status: "completed")
      end)

      insert(:db_migration_status, migration_name: create_migration_name, status: "started")
      Process.sleep(300)

      assert MigrationStatus.get_status(migration_name) == nil
      assert Helper.db_index_exists_and_valid?(@index_name) == %{exists?: true, valid?: true}

      # Once the create migration is completed, the drop proceeds
      MigrationStatus.set_status(create_migration_name, "completed")
      Process.sleep(300)

      assert MigrationStatus.get_status(migration_name) == "completed"
      assert Helper.db_index_exists_and_valid?(@index_name) == %{exists?: false, valid?: nil}
    end
  end
end
