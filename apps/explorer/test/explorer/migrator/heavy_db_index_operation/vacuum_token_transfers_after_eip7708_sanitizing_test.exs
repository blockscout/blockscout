# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.VacuumTokenTransfersAfterEip7708SanitizingTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus, SanitizeEip7708TokenTransfers}
  alias Explorer.Migrator.HeavyDbIndexOperation.VacuumTokenTransfersAfterEip7708Sanitizing
  alias Explorer.Repo

  @migration_name "heavy_indexes_vacuum_token_transfers_after_eip7708_sanitizing"
  @sanitizer_migration_name SanitizeEip7708TokenTransfers.migration_name()

  # `VACUUM` cannot run inside a transaction block, so these tests use a connection which
  # is not wrapped into the sandbox transaction and clean the migration statuses up on
  # their own.
  setup do
    configuration = Application.get_env(:explorer, HeavyDbIndexOperation)
    Application.put_env(:explorer, HeavyDbIndexOperation, Keyword.merge(configuration || [], check_interval: 200))

    :ok = Sandbox.checkout(Repo, sandbox: false)
    Sandbox.mode(Repo, {:shared, self()})
    delete_migration_statuses()

    on_exit(fn ->
      Application.put_env(:explorer, HeavyDbIndexOperation, configuration)

      :ok = Sandbox.checkout(Repo, sandbox: false)
      delete_migration_statuses()
      Sandbox.checkin(Repo)
      Sandbox.mode(Repo, :auto)
    end)

    :ok
  end

  test "builds the migration name from the table name and the suffix" do
    assert VacuumTokenTransfersAfterEip7708Sanitizing.migration_name() == @migration_name
    assert VacuumTokenTransfersAfterEip7708Sanitizing.dependent_from_migrations() == [@sanitizer_migration_name]
  end

  test "vacuums the table only after the EIP-7708 token transfers sanitizer is completed" do
    vacuum_count_before = vacuum_count()

    {:ok, pid} = VacuumTokenTransfersAfterEip7708Sanitizing.start_link([])
    ref = Process.monitor(pid)
    Process.sleep(300)

    # Should not start until the sanitizer is completed
    assert MigrationStatus.get_status(@migration_name) == nil

    MigrationStatus.set_status(@sanitizer_migration_name, "started")
    Process.sleep(300)

    assert MigrationStatus.get_status(@migration_name) == nil

    MigrationStatus.set_status(@sanitizer_migration_name, "completed")
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, :timer.seconds(30)

    assert %{status: "completed", meta: %{"db_operation_finished" => true}} = MigrationStatus.fetch(@migration_name)
    assert vacuum_count() == vacuum_count_before + 1
  end

  test "doesn't vacuum the table again when the migration is already completed" do
    MigrationStatus.set_status(@sanitizer_migration_name, "completed")
    MigrationStatus.set_status(@migration_name, "completed")

    vacuum_count_before = vacuum_count()

    assert VacuumTokenTransfersAfterEip7708Sanitizing.start_link([]) == :ignore
    assert vacuum_count() == vacuum_count_before
  end

  defp delete_migration_statuses do
    Repo.delete_all(
      from(ms in MigrationStatus, where: ms.migration_name in [@migration_name, @sanitizer_migration_name])
    )
  end

  defp vacuum_count do
    # The cumulative statistics are flushed with a delay
    Process.sleep(1_500)

    %{rows: [[count]]} =
      Repo.query!("SELECT vacuum_count FROM pg_stat_user_tables WHERE relname = 'token_transfers'")

    count
  end
end
