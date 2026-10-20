# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.ValidateLogsFirstTopicIdFkeyTest do
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog

  alias Explorer.Migrator.{FillLogsOptimizedFields, HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.ValidateLogsFirstTopicIdFkey

  describe "Validates `logs_first_topic_id_fkey`" do
    setup do
      configuration = Application.get_env(:explorer, HeavyDbIndexOperation)
      Application.put_env(:explorer, HeavyDbIndexOperation, Keyword.merge(configuration || [], check_interval: 200))

      on_exit(fn ->
        Application.put_env(:explorer, HeavyDbIndexOperation, configuration)
      end)

      :ok
    end

    test "reports the constraint created NOT VALID as not initialized and the validated one as completed" do
      refute constraint_validated?()
      assert ValidateLogsFirstTopicIdFkey.db_index_operation_status() == :not_initialized

      Repo.query!("ALTER TABLE logs VALIDATE CONSTRAINT logs_first_topic_id_fkey")

      assert ValidateLogsFirstTopicIdFkey.db_index_operation_status() == :completed
    end

    test "reports a missing constraint as unknown" do
      Repo.query!("ALTER TABLE logs RENAME CONSTRAINT logs_first_topic_id_fkey TO logs_first_topic_id_fkey_renamed")

      assert capture_log(fn ->
               assert ValidateLogsFirstTopicIdFkey.db_index_operation_status() == :unknown
             end) =~ "Constraint logs_first_topic_id_fkey is not found on the logs table"
    end

    test "ignores a constraint with the same name on another table" do
      Repo.query!("CREATE TABLE same_constraint_name (id integer CONSTRAINT logs_first_topic_id_fkey CHECK (id > 0))")

      assert ValidateLogsFirstTopicIdFkey.db_index_operation_status() == :not_initialized
    end

    test "validates the constraint left NOT VALID on an existing install" do
      # with blocks in the DB `init/1` leaves the validation to the status checks
      insert(:block)
      insert(:db_migration_status, migration_name: FillLogsOptimizedFields.migration_name(), status: "completed")

      {:ok, pid} = ValidateLogsFirstTopicIdFkey.start_link([])
      ref = Process.monitor(pid)

      # `:noproc` if the operation stops before the monitor is set up
      assert_receive {:DOWN, ^ref, :process, ^pid, reason} when reason in [:normal, :noproc], 2_000
      assert MigrationStatus.get_status(ValidateLogsFirstTopicIdFkey.migration_name()) == "completed"
      assert constraint_validated?()
    end

    test "validates the constraint only after logs optimized fields are filled" do
      insert(:block)
      migration_name = ValidateLogsFirstTopicIdFkey.migration_name()

      {:ok, pid} = ValidateLogsFirstTopicIdFkey.start_link([])
      ref = Process.monitor(pid)
      Process.sleep(100)

      assert MigrationStatus.get_status(migration_name) == nil
      refute constraint_validated?()

      insert(:db_migration_status, migration_name: FillLogsOptimizedFields.migration_name(), status: "completed")

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
      assert MigrationStatus.get_status(migration_name) == "completed"
      assert constraint_validated?()
    end
  end

  defp constraint_validated? do
    %{rows: [[validated?]]} =
      Repo.query!(
        "SELECT convalidated FROM pg_constraint WHERE conrelid = 'logs'::regclass AND conname = 'logs_first_topic_id_fkey'"
      )

    validated?
  end
end
