# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.RemoveLogsObsoleteColumnsTest do
  use Explorer.DataCase, async: false

  alias Explorer.{Chain, TestHelper}
  alias Explorer.Chain.Log
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.RemoveLogsObsoleteColumns

  @obsolete_columns ~w(address_hash block_hash data first_topic transaction_hash)
  @foreign_keys ~w(logs_block_hash_fkey logs_transaction_hash_fkey)

  @first_topic "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  describe "Removes obsolete columns from `logs`" do
    setup do
      configuration = Application.get_env(:explorer, HeavyDbIndexOperation)
      Application.put_env(:explorer, HeavyDbIndexOperation, Keyword.merge(configuration || [], check_interval: 200))

      on_exit(fn ->
        Application.put_env(:explorer, HeavyDbIndexOperation, configuration)
      end)

      :ok
    end

    test "removes the columns along with their foreign keys" do
      assert RemoveLogsObsoleteColumns.db_index_operation_status() == :not_initialized
      assert existing_obsolete_columns() == @obsolete_columns
      assert existing_foreign_keys() == @foreign_keys

      assert RemoveLogsObsoleteColumns.db_index_operation() == :ok

      assert RemoveLogsObsoleteColumns.db_index_operation_status() == :completed
      assert existing_obsolete_columns() == []
      assert existing_foreign_keys() == []

      # the operation can be safely restarted after it is interrupted at any step
      assert RemoveLogsObsoleteColumns.restart_db_index_operation() == :ok
      assert RemoveLogsObsoleteColumns.db_index_operation_status() == :completed
    end

    test "keeps logs importable and readable without the columns" do
      assert RemoveLogsObsoleteColumns.db_index_operation() == :ok

      %{block: block} = transaction = :transaction |> insert() |> with_block()
      address = insert(:address)

      assert {:ok, %{logs: [_]}} =
               Chain.import(%{
                 logs: %{
                   params: [
                     %{
                       address_hash: to_string(address.hash),
                       block_hash: to_string(block.hash),
                       block_number: block.number,
                       data: "0x01",
                       first_topic: @first_topic,
                       index: 0,
                       transaction_hash: to_string(transaction.hash),
                       transaction_index: transaction.index
                     }
                   ]
                 }
               })

      first_topic = TestHelper.topic(@first_topic)
      block_hash = block.hash
      transaction_hash = transaction.hash
      address_hash = address.hash

      assert [
               %Log{
                 address_hash: ^address_hash,
                 block_hash: ^block_hash,
                 data: %Explorer.Chain.Data{bytes: <<1>>},
                 first_topic: ^first_topic,
                 index: 0,
                 transaction_hash: ^transaction_hash
               }
             ] = Chain.transaction_to_logs(transaction.hash)

      assert [%Log{index: 0, first_topic: ^first_topic}] = Chain.address_to_logs(address.hash, false)
    end

    test "removes the columns only after the dependent migrations are completed" do
      insert(:block)
      migration_name = RemoveLogsObsoleteColumns.migration_name()

      {:ok, pid} = RemoveLogsObsoleteColumns.start_link([])
      ref = Process.monitor(pid)
      Process.sleep(300)

      assert MigrationStatus.get_status(migration_name) == nil
      assert existing_obsolete_columns() == @obsolete_columns

      Enum.each(RemoveLogsObsoleteColumns.dependent_from_migrations(), fn dependent_migration_name ->
        insert(:db_migration_status, migration_name: dependent_migration_name, status: "completed")
      end)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
      assert MigrationStatus.get_status(migration_name) == "completed"
      assert existing_obsolete_columns() == []
    end
  end

  defp existing_obsolete_columns do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT column_name::text
        FROM information_schema.columns
        WHERE table_name = 'logs' AND column_name::text = ANY($1)
        ORDER BY column_name
        """,
        [@obsolete_columns]
      )

    List.flatten(rows)
  end

  defp existing_foreign_keys do
    %{rows: rows} =
      Repo.query!(
        "SELECT conname::text FROM pg_constraint WHERE conrelid = 'logs'::regclass AND conname::text = ANY($1) ORDER BY conname",
        [@foreign_keys]
      )

    List.flatten(rows)
  end
end
